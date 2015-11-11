import std.exception;
import std.stdio;
import std.file;
import std.ascii;
import std.string;
import std.conv;
import std.traits;
import std.algorithm;
import std.array;
import std.path;

import core.stdc.stdlib;

import common.opcode;
import common.cpu;

struct Token
{
	enum Type
	{
		Identifier,
		Number,
		Register,
		Label,
		Byte,
		Dbyte,
		Qbyte
	}

	string fileName;
	int lineNumber;
	int column;

	Type type;
	string text;
	int number;

	string toString()
	{
		return "%s:%s".format(type, text);
	}
}

void error(Args...)(string text, auto ref Args args)
{
	writefln(text, args);
	exit(EXIT_FAILURE);
}

void errorIf(Args...)(bool condition, auto ref Args args)
{
	if (condition)
		error(args);
}

void error(Args...)(ref Token token, string text, auto ref Args args)
{
	writef("%s[%s,%s]: ", token.fileName, token.lineNumber, token.column);
	error(text, args);
}

void attemptTokeniseRegister(ref Token token)
{
	auto t = token.text;
	if (t == "ip")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.IP;
	}
	else if (t == "sp")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.SP;
	}
	else if (t == "bp")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.BP;
	}
	else if (t == "ra")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.RA;
	}
	else if (t == "z")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.Z;
	}
	else if (t.startsWith("r") && t.length > 1 && t[1..$].all!isDigit)
	{
		token.type = Token.Type.Register;
		token.number = t[1..$].to!ubyte();
	}
}

Token[] tokenise(string input, string fileName)
{
	Token[] tokens;
	Token currentToken;

	int lineNumber = 0;
	int column = 0;

	void makeToken()
	{
		currentToken = Token();
		currentToken.fileName = fileName;
	}

	makeToken();

	void completeToken()
	{
		if (currentToken.text.length == 0)
			return;

		if (currentToken.type == Token.Type.Number)
			currentToken.number = currentToken.text.to!int();
		else if (currentToken.type == Token.Type.Identifier)
		{
			if (currentToken.text == "byte")
				currentToken.type = Token.Type.Byte;
			else if (currentToken.text == "dbyte")
				currentToken.type = Token.Type.Dbyte;
			else if (currentToken.text == "qbyte")
				currentToken.type = Token.Type.Qbyte;
			else
				currentToken.attemptTokeniseRegister();
		}

		currentToken.lineNumber = lineNumber;

		tokens ~= currentToken;
		makeToken();
	}

	bool lexingComment = false;
	foreach (line; input.lineSplitter)
	{
		++lineNumber;
		column = 0;

		lexingComment = false;
		currentToken.lineNumber = lineNumber;
		foreach (c; line)
		{
			++column;
			currentToken.column = column;

			if (lexingComment)
				break;

			if (c.isWhite())
			{
				completeToken();
			}
			else if (c == '#')
			{
				lexingComment = true;
			}
			else if (c == ',')
			{
				continue;
			}
			else if (currentToken.text.length == 0 && (c.isDigit() || c == '-'))
			{
				currentToken.type = Token.Type.Number;
				currentToken.text ~= c;
			}
			else if (currentToken.type == Token.Type.Number)
			{
				if (!c.isDigit())
					currentToken.error("Expected digit; got `%s`.", c);
				currentToken.text ~= c;
			}
			else if (currentToken.type == Token.Type.Identifier && (c.isAlphaNum() || c == '_'))
			{
				currentToken.text ~= c;
			}
			else if (currentToken.type == Token.Type.Identifier && c == ':')
			{
				currentToken.type = Token.Type.Label;
			}
			else
			{
				currentToken.error("Invalid character `%s` for token `%s`", c, currentToken.to!string());
			}
		}
		completeToken();
	}

	return tokens;
}

struct Assembler
{
	struct Relocation
	{
		enum Type
		{
			// Offset from this instruction to the target
			Offset,
			// Upper and lower 16-bits of the label, to be stored in the next two instructions
			SplitAbsolute
		}

		string label;
		size_t location;
		Type type;
	}

	Token[] tokens;
	uint[] output;
	uint[string] labels;
	OpcodeDescriptor[][string] descriptors;
	Relocation[] relocations;
	size_t repCount = 1;

	alias AssembleFunction = bool delegate(const(OpcodeDescriptor)* descriptor);
	immutable AssembleFunction[string] pseudoAssemble;

	this(Token[] tokens)
	{
		this.tokens = tokens;

		foreach (member; EnumMembers!Opcodes)
			this.descriptors[member.name] ~= member;

		// Construct the AA of pseudoinstructions => assemble functions
		auto generatePseudoAssemble()
		{
			string ret = "[";

			foreach (member; EnumMembers!Opcodes)
				static if (member.operandFormat == OperandFormat.Pseudo)
					ret ~= (`"%s" : &assemble%s, `).format(member.name, member.to!string);

			ret ~= "]";

			return ret;
		}

		this.pseudoAssemble = mixin(generatePseudoAssemble());
	}

	bool parseNumber(Int)(ref Token[] tokens, ref Int output)
		if (is(Int : int))
	{
		auto token = tokens.front;
		if (token.type != Token.Type.Number)
			return false;

		output = cast(Int)token.number;
		tokens.popFront();
		return true;
	}

	bool parseSizePrefix(ref Token[] tokens, ref OperandSize output)
	{
		auto token = tokens.front;

		if (token.type == Token.Type.Byte)
		{
			tokens.popFront();
			output = OperandSize.Byte;
		}
		else if (token.type == Token.Type.Dbyte)
		{
			tokens.popFront();
			output = OperandSize.Dbyte;
		}
		else if (token.type == Token.Type.Qbyte)
		{
			tokens.popFront();
			output = OperandSize.Qbyte;
		}
		else
		{
			output = OperandSize.Qbyte;
		}

		return true;
	}

	bool parseRegister(ref Token[] tokens, ref ubyte output)
	{
		auto token = tokens.front;
		if (token.type != Token.Type.Register)
			return false;

		output = cast(ubyte)token.number;
		tokens.popFront();
		return true;
	}

	bool parseLabel(ref Token[] tokens, ref string output)
	{
		auto token = tokens.front;
		if (token.type != Token.Type.Identifier)
			return false;

		auto ptr = token.text in this.labels;
		if (!ptr)
			return false;

		output = token.text;
		tokens.popFront();

		return true;
	}

	void finishAssemble(Token[] tokens)
	{
		this.tokens = tokens;
		this.repCount = 1;
	}

	bool assembleDstSrc(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register1, register2;
		if (!this.parseSizePrefix(newTokens, operandSize)) return false;
		if (!this.parseRegister(newTokens, register1)) return false;
		if (!this.parseRegister(newTokens, register2)) return false;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.operandSize = operandSize;
		opcode.register1 = register1;
		opcode.register2 = register2;
		opcode.register3 = 0;

		foreach (_; 0..this.repCount)
			this.output ~= opcode.value;
		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleDstSrcSrc(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register1, register2, register3;
		if (!this.parseSizePrefix(newTokens, operandSize)) return false;
		if (!this.parseRegister(newTokens, register1)) return false;
		if (!this.parseRegister(newTokens, register2)) return false;
		if (!this.parseRegister(newTokens, register3)) return false;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.register1 = register1;
		opcode.register2 = register2;
		opcode.register3 = register3;

		foreach (_; 0..this.repCount)
			this.output ~= opcode.value;
		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleDstImm(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		ubyte register1;
		int immediate;
		if (!this.parseRegister(newTokens, register1)) return false;
		if (!this.parseNumber(newTokens, immediate)) return false;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.register1 = register1;
		opcode.immediate = immediate;

		foreach (_; 0..this.repCount)
			output ~= opcode.value;
		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleNone(const(OpcodeDescriptor)* descriptor)
	{
		Opcode opcode;
		opcode.opcode = descriptor.opcode;

		foreach (_; 0..this.repCount)
			this.output ~= opcode.value;

		return true;
	}

	bool assembleLabel(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;

		string label;
		if (!this.parseLabel(newTokens, label)) return false;

		foreach (_; 0..this.repCount)
		{
			this.output ~= opcode.value;
			this.relocations ~= Relocation(
				label, this.output.length-1, Relocation.Type.Offset);
		}
		this.finishAssemble(newTokens);

		return true;
	}

	bool assemblePush(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register;
		if (!this.parseSizePrefix(newTokens, operandSize)) return false;
		if (!this.parseRegister(newTokens, register)) return false;

		// Synthesize store, add
		Opcode add;
		add.opcode = Opcodes.AddB.opcode;
		add.register1 = Register.SP;
		add.immediate = -4;

		Opcode store;
		store.opcode = Opcodes.Store.opcode;
		store.operandSize = operandSize;
		store.register1 = Register.SP;
		store.register2 = register;

		foreach (_; 0..this.repCount)
		{
			this.output ~= add.value;
			this.output ~= store.value;
		}

		this.finishAssemble(newTokens);

		return true;
	}

	bool assemblePop(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register;
		if (!this.parseSizePrefix(newTokens, operandSize)) return false;
		if (!this.parseRegister(newTokens, register)) return false;

		// Synthesize load, add
		Opcode load;
		load.opcode = Opcodes.Load.opcode;
		load.operandSize = operandSize;
		load.register1 = register;
		load.register2 = Register.SP;

		Opcode add;
		add.opcode = Opcodes.AddB.opcode;
		add.register1 = Register.SP;
		add.immediate = 4;

		foreach (_; 0..this.repCount)
		{
			this.output ~= load.value;
			this.output ~= add.value;
		}

		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleLoadI(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		ubyte register;
		uint value;
		string label;

		if (!this.parseRegister(newTokens, register)) return false;
		if (!(this.parseNumber(newTokens, value) || this.parseLabel(newTokens, label)))
			return false;

		// Synthesize loadui, loadli
		Opcode loadui;
		loadui.opcode = Opcodes.LoadUi.opcode;
		loadui.register1 = register;
		loadui.immediate = (value >> 16) & 0xFFFF;

		Opcode loadli;
		loadli.opcode = Opcodes.LoadLi.opcode;
		loadli.register1 = register;
		loadli.immediate = value & 0xFFFF;

		foreach (_; 0..this.repCount)
		{
			this.output ~= loadui.value;
			this.output ~= loadli.value;

			if (label.length)
			{
				this.relocations ~= Relocation(
					label, this.output.length - 2, Relocation.Type.SplitAbsolute);
			}
		}

		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleDb(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		int value;
		if (!this.parseNumber(newTokens, value)) return false;

		if (this.repCount % 4 != 0)
			throw new Exception("Expected 4-byte alignment compatibility for db");

		auto b = cast(ubyte)value;

		foreach (i; 0..this.repCount/4)
			output ~= b || b << 8 || b << 16 || b << 24;

		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleRep(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		int repCount;
		if (!this.parseNumber(newTokens, repCount)) return false;
		this.repCount = repCount;
		this.tokens = newTokens;

		return true;
	}

	bool assembleJr(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		ubyte register;
		if (!this.parseRegister(newTokens, register)) return false;

		// Synthesize move
		Opcode move;
		move.opcode = Opcodes.Move.opcode;
		move.register1 = Register.IP;
		move.register2 = register;

		foreach (_; 0..this.repCount)
			this.output ~= move.value;

		this.finishAssemble(newTokens);

		return true;
	}

	void assembleIdentifierToken(ref Token token)
	{
		auto matchingDescriptors = token.text in this.descriptors;
		if (!matchingDescriptors)
			token.error("No matching opcode found for `%s`.", token.text);

		bool foundMatching = false;

		string generateSwitchStatement()
		{
			string s =
`final switch (descriptor.operandFormat)
{
`;
			foreach (member; EnumMembers!OperandFormat)
			{
				if (member == OperandFormat.Pseudo)
					continue;

				s ~= format(
`case OperandFormat.%1$s:
	foundMatching |= this.assemble%1$s(&descriptor);
	break;
`,
				member.to!string());
			}

			s ~=
`case OperandFormat.Pseudo:
	foundMatching |= this.pseudoAssemble[token.text](&descriptor);
	break;
}
`;
			return s;
		}

		this.tokens.popFront();
		foreach (descriptor; *matchingDescriptors)
		{
			mixin (generateSwitchStatement());

			if (foundMatching)
				break;
		}
		if (!foundMatching)
			token.error("No valid overloads for `%s` found.", token.text);
	}

	void assembleLabelToken(ref Token token)
	{
		this.labels[token.text] = cast(uint)(this.output.length * uint.sizeof);
		this.tokens.popFront();
	}

	void assemble()
	{
		// Prefill the labels AA
		foreach (token; this.tokens)
		{
			if (token.type == Token.Type.Label)
			{
				auto text = token.text;
				if (text in this.labels)
					token.error("Redefining label `%s`", text);
				this.labels[token.text] = 0;
			}
		}

		while (!this.tokens.empty)
		{
			auto token = this.tokens.front;

			if (token.type == Token.Type.Identifier)
				this.assembleIdentifierToken(token);
			else if (token.type == Token.Type.Label)
				this.assembleLabelToken(token);
			else
				token.error("Unhandled token: %s.", token.to!string());
		}

		auto opcodes = cast(Opcode[])this.output;
		foreach (const relocation; this.relocations)
		{
			final switch (relocation.type)
			{
			case Relocation.Type.Offset:
				auto location = relocation.location;
				auto currentPosition = location * uint.sizeof;

				opcodes[location].offset =
					cast(int)(this.labels[relocation.label] - currentPosition - 4);
				break;
			case Relocation.Type.SplitAbsolute:
				auto location = relocation.location;
				auto label = this.labels[relocation.label];

				opcodes[location].immediate = (label >> 16) & 0xFFFF;
				opcodes[location+1].immediate = label & 0xFFFF;
				break;
			}
		}
	}
}

void main(string[] args)
{
	errorIf(args.length < 2, "expected at least one argument");
	string inputPath = args[1];
	errorIf(!inputPath.exists(), "%s: No such file or directory", inputPath);
	string outputPath = args.length >= 3 ? args[2] : inputPath.setExtension("bin");

	auto input = inputPath.readText();
	auto tokens = input.tokenise(inputPath);
	auto assembler = Assembler(tokens);
	assembler.assemble();

	std.file.write(outputPath, assembler.output);
}