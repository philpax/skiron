module common.opcode;

import std.bitmanip;

struct Opcode
{
	union
	{
		mixin(bitfields!(
			ubyte, "opcode", 8,
			ubyte, "x", 3,
			ubyte, "register1", 7,
			ubyte, "register2", 7,
			ubyte, "register3", 7));

		mixin(bitfields!(
			ubyte, "", 8,
			ubyte, "", 3,
			ubyte, "", 7,
			ubyte, "immediate", 14));
	}
}

static assert(Opcode.sizeof == uint.sizeof);

enum Encoding
{
	A, // dst, src1, src2
	B  // dst, imm14
}

struct OpcodeDescriptor
{
	string name;
	ubyte opcode;
	Encoding encoding;
}

enum Opcodes
{
	Load  = OpcodeDescriptor("load",  0x00, Encoding.A),
	Store = OpcodeDescriptor("store", 0x01, Encoding.A),
	Move  = OpcodeDescriptor("move",  0x02, Encoding.A),
	AddA  = OpcodeDescriptor("add",   0x03, Encoding.A),
	AddB  = OpcodeDescriptor("add",   0x04, Encoding.B),
	Sub   = OpcodeDescriptor("sub",   0x05, Encoding.A),
	Mul   = OpcodeDescriptor("mul",   0x06, Encoding.A),
	Div   = OpcodeDescriptor("div",   0x07, Encoding.A),
	Not   = OpcodeDescriptor("not",   0x08, Encoding.A),
	And   = OpcodeDescriptor("and",   0x09, Encoding.A),
	Or    = OpcodeDescriptor("or",    0x0A, Encoding.A),
	Xor   = OpcodeDescriptor("xor",   0x0B, Encoding.A),
}