module common.opcode;

import std.bitmanip;

struct Opcode
{
	union
	{
		mixin(bitfields!(
			ubyte, "opcode", 8,
			ubyte, "register1", 7,
			ubyte, "register2", 7,
			ubyte, "register3", 7,
			ubyte, "x", 3));

		mixin(bitfields!(
			ubyte, "", 8,
			ubyte, "", 7,
			int, "immediate", 17));

		mixin(bitfields!(
			ubyte, "", 8,
			int, "offset", 24));

		uint value;
	}
}

static assert(Opcode.sizeof == uint.sizeof);

enum OperandSize
{
	Byte,
	Dbyte,
	Qbyte
}

enum Encoding
{
	A, // dst, src1, src2
	B, // dst, imm17
	C  // imm24 (offset)
}

// Not the same as encoding; dictates how many operands there are
enum OperandFormat
{
	DstSrc,
	DstSrcSrc,
	DstImm,
	Label,
	None
}

struct OpcodeDescriptor
{
	string name;
	ubyte opcode;
	Encoding encoding;
	OperandFormat operandFormat;
}

enum Opcodes
{
	// Memory
	Load	= OpcodeDescriptor("load",		0x00, Encoding.A, OperandFormat.DstSrc),
	Store 	= OpcodeDescriptor("store",		0x01, Encoding.A, OperandFormat.DstSrc),
	LoadLi	= OpcodeDescriptor("loadli",	0x02, Encoding.B, OperandFormat.DstImm),
	LoadUi	= OpcodeDescriptor("loadui",	0x03, Encoding.B, OperandFormat.DstImm),
	Move	= OpcodeDescriptor("move",		0x04, Encoding.A, OperandFormat.DstSrc),
	// Arithmetic
	AddA	= OpcodeDescriptor("add",		0x05, Encoding.A, OperandFormat.DstSrcSrc),
	AddB	= OpcodeDescriptor("add",		0x06, Encoding.B, OperandFormat.DstImm),
	Sub		= OpcodeDescriptor("sub",		0x07, Encoding.A, OperandFormat.DstSrcSrc),
	Mul		= OpcodeDescriptor("mul",		0x08, Encoding.A, OperandFormat.DstSrcSrc),
	Div		= OpcodeDescriptor("div",		0x09, Encoding.A, OperandFormat.DstSrcSrc),
	Not		= OpcodeDescriptor("not",		0x0A, Encoding.A, OperandFormat.DstSrc),
	And		= OpcodeDescriptor("and",		0x0B, Encoding.A, OperandFormat.DstSrcSrc),
	Or		= OpcodeDescriptor("or",		0x0C, Encoding.A, OperandFormat.DstSrcSrc),
	Xor		= OpcodeDescriptor("xor",		0x0D, Encoding.A, OperandFormat.DstSrcSrc),
	// Control flow
	Halt	= OpcodeDescriptor("halt",		0xFF, Encoding.A, OperandFormat.None),
	Cmp		= OpcodeDescriptor("cmp",		0x10, Encoding.A, OperandFormat.DstSrc),
	Je		= OpcodeDescriptor("je",		0x11, Encoding.C, OperandFormat.Label),
	Jne		= OpcodeDescriptor("jne",		0x12, Encoding.C, OperandFormat.Label),
}

unittest
{
	Opcode opcode;
	opcode.opcode = Opcodes.Load.opcode;
	opcode.register1 = 0;
	opcode.register2 = 1;
	opcode.register3 = 2;

	assert(opcode.opcode == Opcodes.Load.opcode);
	assert(opcode.register1 == 0);
	assert(opcode.register2 == 1);
	assert(opcode.register3 == 2);
}

string generateOpcodeToDescriptor()
{
	import std.traits, std.string, std.conv;

	string ret =
`final switch (opcode)
{
`;

	foreach (member; EnumMembers!Opcodes)
		ret ~= "case Opcodes.%s.opcode: return Opcodes.%s;\n".format(
			member.to!string(), member.to!string());

	ret ~= `}`;

	return ret;
}


OpcodeDescriptor opcodeToDescriptor(ubyte opcode) @nogc nothrow
{
	mixin(generateOpcodeToDescriptor());
}

char[] disassemble(Opcode opcode, char[] output) @nogc nothrow
{
	import common.cpu : registerName;
	import core.stdc.stdio : snprintf;

	char[16][3] buffers;

	auto descriptor = opcode.opcode.opcodeToDescriptor();
	final switch (descriptor.operandFormat)
	{
	case OperandFormat.DstSrc:
		auto reg1 = opcode.register1.registerName(buffers[0]);
		auto reg2 = opcode.register2.registerName(buffers[1]);

		auto length =
			snprintf(output.ptr, output.length, "%.*s %.*s, %.*s",
				descriptor.name.length, descriptor.name.ptr,
				reg1.length, reg1.ptr, reg2.length, reg2.ptr);

		return output[0..length];
	case OperandFormat.DstSrcSrc:
		auto reg1 = opcode.register1.registerName(buffers[0]);
		auto reg2 = opcode.register2.registerName(buffers[1]);
		auto reg3 = opcode.register3.registerName(buffers[2]);

		string sizePrefix;
		final switch (cast(OperandSize)opcode.x)
		{
		case OperandSize.Byte:
			sizePrefix = "byte";
			break;
		case OperandSize.Dbyte:
			sizePrefix = "dbyte";
			break;
		case OperandSize.Qbyte:
			sizePrefix = "qbyte";
			break;
		}

		auto length =
			snprintf(output.ptr, output.length, "%.*s %.*s %.*s, %.*s, %.*s",
				descriptor.name.length, descriptor.name.ptr,
				sizePrefix.length, sizePrefix.ptr,
				reg1.length, reg1.ptr, reg2.length, reg2.ptr, reg3.length, reg3.ptr);

		return output[0..length];
	case OperandFormat.DstImm:
		auto reg1 = opcode.register1.registerName(buffers[0]);

		auto length =
			snprintf(output.ptr, output.length, "%.*s %.*s, %i",
				descriptor.name.length, descriptor.name.ptr,
				reg1.length, reg1.ptr, opcode.immediate);

		return output[0..length];
	case OperandFormat.Label:
		auto length =
			snprintf(output.ptr, output.length, "%.*s %i",
				descriptor.name.length, descriptor.name.ptr, opcode.offset);

		return output[0..length];
	case OperandFormat.None:
		auto length =
			snprintf(output.ptr, output.length, "%.*s",
				descriptor.name.length, descriptor.name.ptr);

		return output[0..length];
	}

	return output;
}

unittest
{
	Opcode opcode;
	opcode.opcode = Opcodes.Load.opcode;
	opcode.register1 = 0;
	opcode.register2 = 1;

	char[64] buffer;
	auto slice = opcode.disassemble(buffer);

	assert(slice == "load r0, r1");
}