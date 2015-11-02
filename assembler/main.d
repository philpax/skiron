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

OpcodeDescriptor[][string] descriptors;

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

int parseNumber(ref Token[] tokens)
{
	auto token = tokens.front;
	enforce(token.type == Token.Type.Number);

	scope (success) tokens.popFront();
	return token.number;
}

OperandSize parseSizePrefix(ref Token[] tokens)
{
	auto token = tokens.front;

	if (token.type == Token.Type.Byte)
	{
		tokens.popFront();
		return OperandSize.Byte;
	}
	else if (token.type == Token.Type.Dbyte)
	{
		tokens.popFront();
		return OperandSize.Dbyte;
	}
	else if (token.type == Token.Type.Qbyte)
	{
		tokens.popFront();
		return OperandSize.Qbyte;
	}
	else
	{
		return OperandSize.Qbyte;
	}
}

ubyte parseRegister(ref Token[] tokens)
{
	scope (success) tokens.popFront();
	auto token = tokens.front;
	enforce(token.type == Token.Type.Register);

	return cast(ubyte)token.number;
}

int parseLabel(ref Token[] tokens, uint[string] labels)
{
	scope (success) tokens.popFront();
	auto token = tokens.front;
	enforce(token.type == Token.Type.Identifier);

	auto ptr = token.text in labels;
	enforce(ptr);

	return *ptr;
}

struct Assembler
{
	Token[] tokens;
	uint[] output;
	uint[string] labels;

	bool assembleDstSrc(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.operandSize = newTokens.parseSizePrefix();
		try
		{
			opcode.register1 = newTokens.parseRegister();
			opcode.register2 = newTokens.parseRegister();
			opcode.register3 = 0;
		}
		catch (Exception e)
			return false;

		this.output ~= opcode.value;
		this.tokens = newTokens;

		return true;
	}

	bool assembleDstSrcSrc(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.operandSize = newTokens.parseSizePrefix();
		try
		{
			opcode.register1 = newTokens.parseRegister();
			opcode.register2 = newTokens.parseRegister();
			opcode.register3 = newTokens.parseRegister();
		}
		catch (Exception e)
			return false;

		this.output ~= opcode.value;
		this.tokens = newTokens;

		return true;
	}

	bool assembleDstImm(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		try
		{
			opcode.register1 = newTokens.parseRegister();
			opcode.immediate = newTokens.parseNumber();
		}
		catch (Exception e)
			return false;

		output ~= opcode.value;
		tokens = newTokens;

		return true;
	}

	bool assembleNone(const(OpcodeDescriptor)* descriptor)
	{
		Opcode opcode;
		opcode.opcode = descriptor.opcode;

		this.output ~= opcode.value;

		return true;
	}

	bool assembleLabel(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		try
		{
			auto currentPosition = cast(int)(output.length * uint.sizeof);
			auto offset = newTokens.parseLabel(this.labels);
			opcode.offset = offset - currentPosition - 4;
		}
		catch (Exception e)
			return false;

		this.output ~= opcode.value;
		this.tokens = newTokens;

		return true;
	}

	bool assemblePush(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register;
		try
		{
			operandSize = newTokens.parseSizePrefix();
			register = newTokens.parseRegister();
		}
		catch (Exception e)
			return false;

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

		this.output ~= add.value;
		this.output ~= store.value;

		this.tokens = newTokens;

		return true;
	}

	bool assemblePop(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register;
		try
		{
			operandSize = newTokens.parseSizePrefix();
			register = newTokens.parseRegister();
		}
		catch (Exception e)
			return false;

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

		this.output ~= load.value;
		this.output ~= add.value;

		this.tokens = newTokens;

		return true;
	}

	bool assembleLoadI(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		ubyte register;
		int value;
		try
		{
			register = newTokens.parseRegister();
		}
		catch (Exception e)
			return false;

		try
		{
			value = newTokens.parseNumber();
		}
		catch (Exception e)
		{
			try
			{
				value = newTokens.parseLabel(this.labels);
			}
			catch (Exception e)
				return false;
		}

		// Synthesize loadui, loadli
		Opcode loadui;
		loadui.opcode = Opcodes.LoadUi.opcode;
		loadui.register1 = register;
		loadui.immediate = (cast(uint)value >> 16) & 0xFFFF;

		Opcode loadli;
		loadli.opcode = Opcodes.LoadLi.opcode;
		loadli.register1 = register;
		loadli.immediate = cast(uint)value & 0xFFFF;

		this.output ~= loadui.value;
		this.output ~= loadli.value;

		this.tokens = newTokens;

		return true;
	}

	bool assembleDb(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		int count, value;
		try
		{
			count = newTokens.parseNumber();
			value = newTokens.parseNumber();
		}
		catch (Exception e)
			return false;

		foreach (i; 0..count/4)
			output ~= value;

		this.tokens = newTokens;

		return true;
	}
}

alias AssembleFunction = bool delegate(ref Assembler assembler, const(OpcodeDescriptor)* descriptor);
auto generatePseudoAssemble()
{
	string ret = "[";

	foreach (member; EnumMembers!Opcodes)
	{
		static if (member.operandFormat == OperandFormat.Pseudo)
		{
			ret ~= (`"%s" : (ref Assembler assembler, const(OpcodeDescriptor)* descriptor) ` ~
				`=> assembler.assemble%s(descriptor), `).format(member.name, member.to!string);
		}
	}

	ret ~= "]";

	return ret;
}

immutable AssembleFunction[string] PseudoAssemble;

// Use a module constructor to work around not being able to initialize AAs in module scope
static this()
{
	PseudoAssemble = mixin(generatePseudoAssemble());
} 

uint[] assemble(Token[] tokens)
{
	Assembler assembler;
	assembler.tokens = tokens;
	while (!assembler.tokens.empty)
	{
		auto token = assembler.tokens.front;

		if (token.type == Token.Type.Identifier)
		{
			auto descriptors = token.text in descriptors;
			if (!descriptors)
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
	foundMatching |= assembler.assemble%1$s(&descriptor);
	break;
`,
					member.to!string());
				}

				s ~= 
`case OperandFormat.Pseudo:
	foundMatching |= PseudoAssemble[token.text](assembler, &descriptor);
	break;
}
`;
				return s;
			}

			assembler.tokens.popFront();
			foreach (descriptor; *descriptors)
			{
				mixin (generateSwitchStatement());

				if (foundMatching) 
					break;
			}
			if (!foundMatching)
				token.error("No valid overloads for `%s` found.", token.text);
		}
		else if (token.type == Token.Type.Label)
		{
			auto text = token.text;
			if (text in assembler.labels)
				token.error("Redefining label `%s`", text);
			assembler.labels[text] = cast(uint)(assembler.output.length * uint.sizeof);
			assembler.tokens.popFront();
		}
		else
		{
			token.error("Unhandled token: %s.", token.to!string());
		}
	}

	return assembler.output;
}

void main(string[] args)
{
	errorIf(args.length < 2, "expected at least one argument");
	string inputPath = args[1];
	errorIf(!inputPath.exists(), "%s: No such file or directory", inputPath);
	string outputPath = args.length >= 3 ? args[2] : inputPath.setExtension("bin");

	auto input = inputPath.readText();

	foreach (member; EnumMembers!Opcodes)
		descriptors[member.name] ~= member;

	auto tokens = input.tokenise(inputPath);
	auto output = tokens.assemble();

	std.file.write(outputPath, output);
}