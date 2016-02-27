import std.file;
import std.path;
import std.traits;
import std.string, std.ascii;
import std.conv;
import std.range;
import std.algorithm;
import lexer;

import core.stdc.stdlib;

import common.opcode;
import common.cpu;

void error(Args...)(string text, auto ref Args args)
{
	import std.stdio : writefln;
	writefln(text, args);
	exit(EXIT_FAILURE);
}

void errorIf(Args...)(bool condition, auto ref Args args)
{
	if (condition)
		error(args);
}

void error(Args...)(ref const(Token) token, string text, auto ref Args args)
{
	error("[%s,%s]: " ~ text, token.line, token.column, args);
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

	const(Token)[] tokens;
	uint[] output;
	uint[string] labels;
	OpcodeDescriptor[][string] descriptors;
	Relocation[] relocations;
	size_t repCount = 1;

	alias AssembleFunction = bool delegate(const(OpcodeDescriptor)* descriptor);
	immutable AssembleFunction[string] pseudoAssemble;

	this(const(Token)[] tokens)
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

	bool parseNumber(Int)(ref const(Token)[] tokens, ref Int output)
		if (is(Int : int))
	{
		auto token = tokens.front;
		if (token.type != tok!"numberLiteral")
			return false;

		auto text = token.text;
		if (text.startsWith("0x"))
			output = cast(Int)text[2..$].to!long(16);
		else
			output = cast(Int)text.to!long;
		tokens.popFront();
		return true;
	}

	bool parseSizePrefix(ref const(Token)[] tokens, ref OperandSize output)
	{
		auto token = tokens.front;

		if (token.type == tok!"byte")
		{
			tokens.popFront();
			output = OperandSize.Byte;
		}
		else if (token.type == tok!"dbyte")
		{
			tokens.popFront();
			output = OperandSize.Dbyte;
		}
		else if (token.type == tok!"qbyte")
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

	bool parseRegister(ref const(Token)[] tokens, ref ubyte output)
	{
		auto token = tokens.front;
		if (token.type != tok!"identifier")
			return false;

		auto t = token.text;
		if (t == "ip")
			output = cast(ubyte)Register.IP;
		else if (t == "sp")
			output = cast(ubyte)Register.SP;
		else if (t == "bp")
			output = cast(ubyte)Register.BP;
		else if (t == "ra")
			output = cast(ubyte)Register.RA;
		else if (t == "z")
			output = cast(ubyte)Register.Z;
		else if (t.startsWith("r") && t.length > 1 && t[1..$].all!isDigit)
			output = t[1..$].to!ubyte();
		else
			return false;

		tokens.popFront();
		return true;
	}

	bool parseLabel(ref const(Token)[] tokens, ref string output)
	{
		auto token = tokens.front;
		if (token.type != tok!"identifier")
			return false;

		auto ptr = token.text in this.labels;
		if (!ptr)
			return false;

		output = token.text;
		tokens.popFront();

		return true;
	}

	bool parseVariant(ref const(Token)[] tokens, ref Variant output)
	{
		Token token = tokens.front;

		if (token.type == tok!"<<")
		{
			tokens.popFront();

			int shift;
			if (!this.parseNumber(tokens, shift))
			{
				token.error("Expected number in shift");
				return false;
			}

			if (shift == 1)
			{
				output = Variant.ShiftLeft1;
			}
			else if (shift == 2)
			{
				output = Variant.ShiftLeft2;
			}
			else
			{
				token.error("Shift size not encodable");
				return false;
			}
		}
		else
		{
			// TODO: Look into why exactly Variant.Default doesn't work
			output = cast(Variant)0;
		}

		return true;
	}

	void finishAssemble(const(Token)[] tokens)
	{
		this.tokens = tokens;
		this.repCount = 1;
	}

	bool assembleDstSrc(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register1, register2;
		Variant variant;
		if (!this.parseSizePrefix(newTokens, operandSize)) return false;
		if (!this.parseRegister(newTokens, register1)) return false;
		if (!this.parseRegister(newTokens, register2)) return false;
		if (!this.parseVariant(newTokens, variant)) return false;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.operandSize = operandSize;
		opcode.register1 = register1;
		opcode.register2 = register2;
		opcode.register3 = 0;
		opcode.variant = variant;

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
		Variant variant;
		if (!this.parseSizePrefix(newTokens, operandSize)) return false;
		if (!this.parseRegister(newTokens, register1)) return false;
		if (!this.parseRegister(newTokens, register2)) return false;
		if (!this.parseRegister(newTokens, register3)) return false;
		if (!this.parseVariant(newTokens, variant)) return false;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.operandSize = operandSize;
		opcode.register1 = register1;
		opcode.register2 = register2;
		opcode.register3 = register3;
		opcode.variant = variant;

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
		Variant variant;
		if (!this.parseRegister(newTokens, register1)) return false;
		if (!this.parseNumber(newTokens, immediate)) return false;
		if (!this.parseVariant(newTokens, variant)) return false;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.register1 = register1;
		opcode.immediate = immediate;
		opcode.variant = variant;

		foreach (_; 0..this.repCount)
			output ~= opcode.value;
		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleDstSrcImm(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		OperandSize operandSize;
		ubyte register1, register2;
		int immediate;
		Variant variant;
		if (!this.parseSizePrefix(newTokens, operandSize)) return false;
		if (!this.parseRegister(newTokens, register1)) return false;
		if (!this.parseRegister(newTokens, register2)) return false;
		if (!this.parseNumber(newTokens, immediate)) return false;
		if (!this.parseVariant(newTokens, variant)) return false;

		Opcode opcode;
		opcode.opcode = descriptor.opcode;
		opcode.register1 = register1;
		opcode.register2 = register2;
		opcode.immediate9 = immediate;
		opcode.variant = variant;

		foreach (_; 0..this.repCount)
			this.output ~= opcode.value;
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
		int value;
		string label;

		if (!this.parseRegister(newTokens, register)) return false;
		if (!(this.parseNumber(newTokens, value) || this.parseLabel(newTokens, label)))
			return false;

		void writeLoadPair()
		{
			ushort high = (value >> 16) & 0xFFFF;
			ushort low =  (value >>  0) & 0xFFFF;

			// Synthesize loadui, loadli
			Opcode loadui;
			loadui.opcode = Opcodes.LoadUi.opcode;
			loadui.register1 = register;
			loadui.immediate = *cast(short*)&high;

			Opcode loadli;
			loadli.opcode = Opcodes.LoadLi.opcode;
			loadli.register1 = register;
			loadli.immediate = *cast(short*)&low;

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
		}

		// If we're dealing with a value, and it can be packed into 11 bits
		if (label.empty && (value & 0b0000_0111_1111_1111) == value)
		{
			Opcode add;
			add.opcode = Opcodes.AddD.opcode;
			add.register1 = register;
			add.register2 = Register.Z;

			// If the value can be packed into 9 bits, multiplied by 1
			if ((value & 0b0000_0001_1111_1111) == value)
			{
				add.immediate9 = (value & 0b0000_0001_1111_1111) >> 0;
				add.variant = Variant.Identity;

				foreach (_; 0..this.repCount)
					this.output ~= add.value;
			}
			// If the value can be packed into 9 bits, multiplied by 2
			else if ((value & 0b0000_0011_1111_1110) == value)
			{
				add.immediate9 = (value & 0b0000_0011_1111_1110) >> 1;
				add.variant = Variant.ShiftLeft1;

				foreach (_; 0..this.repCount)
					this.output ~= add.value;
			}
			// If the value can be packed into 9 bits, multiplied by 4
			else if ((value & 0b0000_0111_1111_1100) == value)
			{
				add.immediate9 = (value & 0b0000_0111_1111_1100) >> 2;
				add.variant = Variant.ShiftLeft2;

				foreach (_; 0..this.repCount)
					this.output ~= add.value;
			}
			// Otherwise, give up and write a load pair
			else
			{
				writeLoadPair();
			}
		}
		else
		{
			// Can't be packed into an add opcode; write a load pair
			writeLoadPair();
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

		// Synthesize add
		Opcode add;
		add.opcode = Opcodes.AddA.opcode;
		add.operandSize = OperandSize.Qbyte;
		add.register1 = Register.IP;
		add.register2 = register;
		add.register3 = Register.Z;

		foreach (_; 0..this.repCount)
			this.output ~= add.value;

		this.finishAssemble(newTokens);

		return true;
	}

	bool assembleMove(const(OpcodeDescriptor)* descriptor)
	{
		auto newTokens = this.tokens;

		ubyte dst, src;
		if (!this.parseRegister(newTokens, dst)) return false;
		if (!this.parseRegister(newTokens, src)) return false;

		// Synthesize add
		Opcode add;
		add.opcode = Opcodes.AddA.opcode;
		add.operandSize = OperandSize.Qbyte;
		add.register1 = dst;
		add.register2 = src;
		add.register3 = Register.Z;

		foreach (_; 0..this.repCount)
			this.output ~= add.value;

		this.finishAssemble(newTokens);

		return true;
	}

	void assembleIdentifierToken(ref const(Token) token)
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

	void assembleLabelToken(ref const(Token) token)
	{
		this.labels[token.text] = cast(uint)(this.output.length * uint.sizeof);
		this.tokens.popFront();
	}

	void assemble()
	{
		// Prefill the labels AA
		foreach (token; this.tokens)
		{
			if (token.type == tok!"label")
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

			if (token.type == tok!"identifier")
				this.assembleIdentifierToken(token);
			else if (token.type == tok!"label")
				this.assembleLabelToken(token);
			else if (token.type == tok!"")
				break;
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

	auto tokens = (cast(ubyte[])inputPath.read()).tokenise();
	auto assembler = Assembler(tokens);
	assembler.assemble();

	std.file.write(outputPath, assembler.output);
}