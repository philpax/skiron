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
			ubyte, "immediate", 17));
	}
}

static assert(Opcode.sizeof == uint.sizeof);

enum Encoding
{
	A, // dst, src1, src2
	B  // dst, imm17
}

struct OpcodeDescriptor
{
	string name;
	ubyte opcode;
	Encoding encoding;
}

enum Opcodes
{
	Load	= OpcodeDescriptor("load",		0x00, Encoding.A),
	Store 	= OpcodeDescriptor("store",		0x01, Encoding.A),
	LoadLi	= OpcodeDescriptor("loadli",	0x02, Encoding.B),
	LoadUi	= OpcodeDescriptor("loadui",	0x03, Encoding.B),
	Move	= OpcodeDescriptor("move",		0x04, Encoding.A),
	AddA	= OpcodeDescriptor("add",		0x05, Encoding.A),
	AddB	= OpcodeDescriptor("add",		0x06, Encoding.B),
	Sub		= OpcodeDescriptor("sub",		0x07, Encoding.A),
	Mul		= OpcodeDescriptor("mul",		0x08, Encoding.A),
	Div		= OpcodeDescriptor("div",		0x09, Encoding.A),
	Not		= OpcodeDescriptor("not",		0x0A, Encoding.A),
	And		= OpcodeDescriptor("and",		0x0B, Encoding.A),
	Or		= OpcodeDescriptor("or",		0x0C, Encoding.A),
	Xor		= OpcodeDescriptor("xor",		0x0D, Encoding.A),
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