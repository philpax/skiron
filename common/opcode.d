module common.opcode;

import common.cpu;
import common.util;
import common.encoding;

import std.traits : EnumMembers;

enum OpcodeBitCount = 6;
enum OpcodeCount = (1 << OpcodeBitCount);
alias Identity(alias A) = A;

mixin EnumDocumentedDefault!("Variant",
	"Identity",
		"Pass the operand through unchanged.",
	"ShiftLeft1",
		"Shift the operand 1 bit to the left.",
	"ShiftLeft2",
		"Shift the operand 2 bits to the left.",
);

enum Encoding
{
	A,
	B,
	C,
	D,
}

struct Opcode
{
	union
	{
		enum EncodingBitCount = 2;
		enum VariantBitCount = 2;
		enum OperandSizeBitCount = 2;

		mixin DefineEncoding!(Encoding.A,
			"Used for three-register instructions.",
			ubyte,			"opcode",		OpcodeBitCount,
			"The opcode number.",
			Encoding,		"encoding",		EncodingBitCount,
			"The encoding in use.",
			Variant,		"variant",		VariantBitCount,
			"The variant/modifier to apply to register3.",
			Register,		"register1",	RegisterBitCount,
			"The destination register.",
			Register,		"register2",	RegisterBitCount,
			"The first source register.",
			Register,		"register3",	RegisterBitCount,
			"The second source register.",
			ubyte,			"_padding",		2,
			"",
			OperandSize,	"operandSize",	OperandSizeBitCount,
			"The sizes of the operands being used.",
		);

		mixin DefineEncoding!(Encoding.B,
			"Used for one-register, one-immediate instructions.",
			ubyte,			"opcode",		OpcodeBitCount,
			"",
			Encoding,		"encoding",		EncodingBitCount,
			"",
			Variant,		"variant",		VariantBitCount,
			"The variant/modifier to apply to the immediate.",
			Register,		"register1",	RegisterBitCount,
			"The destination/source register.",
			ushort,			"immediate",	16,
			"The encoded unsigned immediate value.",
		);

		mixin DefineEncoding!(Encoding.C,
			"Used for one-immediate instructions.",
			ubyte,			"opcode",		OpcodeBitCount,
			"",
			Encoding,		"encoding",		EncodingBitCount,
			"",
			Variant,		"variant",		VariantBitCount,
			"The variant/modifier to apply to the immediate.",
			int,			"immediate",	20,
			"The encoded signed immediate value.",
			OperandSize,	"operandSize",	OperandSizeBitCount,
			"",
		);

		mixin DefineEncoding!(Encoding.D,
			"Used for two-register, one-immediate instructions.",
			ubyte,			"opcode",		OpcodeBitCount,
			"",
			Encoding,		"encoding",		EncodingBitCount,
			"",
			Variant,		"variant",		VariantBitCount,
			"The variant/modifier to apply to the immediate.",
			Register,		"register1",	RegisterBitCount,
			"The destination register.",
			Register,		"register2",	RegisterBitCount,
			"The source register.",
			int,			"immediate",	8,
			"The encoded signed immediate value.",
			OperandSize,	"operandSize",	OperandSizeBitCount,
			"",
		);

		uint value;
	}
}

static assert(Opcode.sizeof == uint.sizeof);

public:

enum OperandSize
{
	Byte = 0,
	Byte1 = Byte,
	Byte2,
	Byte4,
	Word = Byte4
}

struct OperandFormatDescriptor
{
	string name;
	Encoding encoding;
	bool supportsOperandSize;
	string description;
}

// Ordering of this enum is important.
// It controls the order in which metaprogramming code, including the
// assembler, will choose to handle operand formats.
// More complex formats should come first to ensure that more complex
// parses are attempted before simpler parsers.
enum OperandFormat
{
	DstSrcImm	= OperandFormatDescriptor("DstSrcImm", Encoding.D, true,
		"Destination (register), source1 (register), source2 (immediate)"),
	DstSrcSrc	= OperandFormatDescriptor("DstSrcSrc", Encoding.A, true,
		"Destination (register), source (register), source (register)"),
	DstSrc		= OperandFormatDescriptor("DstSrc", Encoding.A, true,
		"Destination (register), source (register)"),
	DstUimm		= OperandFormatDescriptor("DstUimm", Encoding.B, false,
		"Destination (register), source (unsigned immediate)"),
	Label		= OperandFormatDescriptor("Label", Encoding.C, false,
		"Label (immediate)"),
	Dst			= OperandFormatDescriptor("Dst", Encoding.A, true,
		"Destination (register)"),
	Uimm		= OperandFormatDescriptor("Uimm", Encoding.B, false,
		"Source (unsigned immediate)"),
	None		= OperandFormatDescriptor("None", Encoding.A, false,
		"No operands")
}

auto sortIndex(OperandFormatDescriptor ofd)
{
	size_t index = 0;
	foreach (operandFormat; EnumMembers!OperandFormat)
	{
		if (operandFormat.name == ofd.name)
		{
			return index;
		}

		index++;
	}

	assert(false);
}

struct OpcodeDescriptor
{
	string name;
	ubyte opcode;
	OperandFormat operandFormat;
	string description;
	string operation;
	bool pseudoOpcode;

	@property Encoding encoding() const @nogc nothrow
	{
		return this.operandFormat.encoding;
	}
}

auto PseudoOpcode(string name, OperandFormat operandFormat, string description, string operation = "")
{
	return OpcodeDescriptor(name, 0, operandFormat, description, operation, true);
}

enum Opcodes
{
	// Memory
	Load	= OpcodeDescriptor("load",		0,  OperandFormat.DstSrc,
		"Loads the value located in `[src]` into `dst`."),
	Store 	= OpcodeDescriptor("store",		1,  OperandFormat.DstSrc,
		"Stores the value located in `src` into `[dst]`."),
	LoadLi	= OpcodeDescriptor("loadli",	2,  OperandFormat.DstUimm,
		"Load the immediate into the lower half of `src`."),
	LoadUi	= OpcodeDescriptor("loadui",	3,  OperandFormat.DstUimm,
		"Load the immediate into the upper half of `src`."),
	// Arithmetic
	AddA	= OpcodeDescriptor("add",		4,  OperandFormat.DstSrcSrc,
		"Add `src1` to `src2`, and store the result in `dst`.",
		q{$dst = $src1 + $src2}),
	AddB	= OpcodeDescriptor("add",		4, OperandFormat.DstSrc,
		"Add `imm` to `src`, and store the result in `dst`.",
		q{$dst = $dst + $imm}),
	AddD	= OpcodeDescriptor("add",		4, OperandFormat.DstSrcImm,
		"Add `imm` to `dst`, and store the result in `dst`.",
		q{$dst = $src + $imm}),

	SubA	= OpcodeDescriptor("sub",		7,  OperandFormat.DstSrcSrc,
		"Subtract `src2` from `src1`, and store the result in `dst`.",
		q{$dst = $src1 - $src2}),
	SubB	= OpcodeDescriptor("sub",		7,  OperandFormat.DstSrc,
		"Subtract `imm` from `src`, and store the result in `dst`.",
		q{$dst = $dst - $imm}),
	SubD	= OpcodeDescriptor("sub",		7,  OperandFormat.DstSrcImm,
		"Subtract `imm` from `dst`, and store the result in `dst`.",
		q{$dst = $src - $imm}),

	MulA	= OpcodeDescriptor("mul",		8,  OperandFormat.DstSrcSrc,
		"Multiply `src1` by `src2`, and store the result in `dst`.",
		q{$dst = $src1 * $src2}),
	MulB	= OpcodeDescriptor("mul",		8,  OperandFormat.DstSrc,
		"Multiply `src` by `imm`, and store the result in `dst`.",
		q{$dst = $dst * $imm}),
	MulD	= OpcodeDescriptor("mul",		8,  OperandFormat.DstSrcImm,
		"Multiply `dst` by `imm`, and store the result in `dst`.",
		q{$dst = $src * $imm}),

	DivA	= OpcodeDescriptor("div",		9,  OperandFormat.DstSrcSrc,
		"Divide `src1` by `src2`, and store the result in `dst`.",
		q{$dst = $src1 / $src2}),
	DivB	= OpcodeDescriptor("div",		9,  OperandFormat.DstSrc,
		"Divide `src` by `imm`, and store the result in `dst`.",
		q{$dst = $dst / $imm}),
	DivD	= OpcodeDescriptor("div",		9,  OperandFormat.DstSrcImm,
		"Divide `dst` by `imm`, and store the result in `dst`.",
		q{$dst = $src / $imm}),

	Not		= OpcodeDescriptor("not",		10,  OperandFormat.DstSrc,
		"Bitwise-NOT `src`, and store the result in `dst`.",
		q{$dst = ~$src}),
	And		= OpcodeDescriptor("and",		11,  OperandFormat.DstSrcSrc,
		"Bitwise-AND `src1` with `src2`, and store the result in `dst`.",
		q{$dst = $src1 & $src2}),
	Or		= OpcodeDescriptor("or",		12,  OperandFormat.DstSrcSrc,
		"Bitwise-OR `src1` with `src2`, and store the result in `dst`.",
		q{$dst = $src1 | $src2}),
	Xor		= OpcodeDescriptor("xor",		13,  OperandFormat.DstSrcSrc,
		"Bitwise-XOR `src1` with `src2`, and store the result in `dst`.",
		q{$dst = $src1 ^ $src2}),
	Shl		= OpcodeDescriptor("shl",		14,  OperandFormat.DstSrcSrc,
		"Shift `src1` by `src2` bits to the left, and store the result in `dst`.",
		q{$dst = $src1 << $src2}),
	Shr		= OpcodeDescriptor("shr",		15,  OperandFormat.DstSrcSrc,
		"Shift `src1` by `src2` bits to the right, and store the result in `dst`.",
		q{$dst = $src1 >> $src2}),
	// Control flow
	Cmp		= OpcodeDescriptor("cmp",		16,  OperandFormat.DstSrc,
		"Compare `dst` to `src`, and update the flags register appropriately."),
	J		= OpcodeDescriptor("j",			17,  OperandFormat.Label,
		"Jump to the given label unconditionally."),
	Je		= OpcodeDescriptor("je",		18,  OperandFormat.Label,
		"If the zero flag is set, jump to the given label."),
	Jne		= OpcodeDescriptor("jne",		19,  OperandFormat.Label,
		"If the zero flag is not set, jump to the given label."),
	Jgt		= OpcodeDescriptor("jgt",		20,  OperandFormat.Label,
		"If the greater flag is set, jump to the given label."),
	Jlt		= OpcodeDescriptor("jlt",		21,  OperandFormat.Label,
		"If the less flag is set, jump to the given label."),
	Halt	= OpcodeDescriptor("halt",		OpcodeCount-1,  OperandFormat.None,
		"Halt operation."),
	// Pseudoinstructions
	Push	= PseudoOpcode("push", OperandFormat.Dst,
		"Push the given register onto the stack (i.e. `add sp, -4; store sp, register`)."),
	Pop		= PseudoOpcode("pop", OperandFormat.Dst,
		"Pop the given register from the stack (i.e. `load register, sp; add sp, 4`)."),
	Call	= PseudoOpcode("call", OperandFormat.Label,
		"Store the current instruction pointer in `ra`, and then jump to the given label."),
	CallSv	= PseudoOpcode("callsv", OperandFormat.Label,
		"Push the current return address, call the given label, and pop the return address."),
	LoadI	= PseudoOpcode("loadi", OperandFormat.Uimm,
		"Load the given 32-bit immediate, or label, into a register."),
	Dw		= PseudoOpcode("dw", OperandFormat.None,
		"Create a word containing `arg2`."),
	Rep		= PseudoOpcode("rep", OperandFormat.Uimm,
		"Repeat the following instruction `arg1` times."),
	Jr		= PseudoOpcode("jr", OperandFormat.Label,
		"Jump to the given register."),
	Move	= PseudoOpcode("move", OperandFormat.DstSrc,
		"Copy the value in `src` to `dst`."),
}

auto getOpcodeStructure(OperandFormatDescriptor operandFormat)()
{
	import std.conv : to;
	enum encoding = operandFormat.encoding.to!string();
	return __traits(getMember, Opcode, encoding)();
}

auto asEncodingFromOperandFormat(OperandFormatDescriptor operandFormat)(Opcode opcode)
{
	import std.conv : to;
	alias EncodingType = Identity!(__traits(getMember, opcode, operandFormat.encoding.to!string()));
	return cast(EncodingType)opcode;
}

auto makeOpcode(OpcodeDescriptor opcode)()
{
	enum operandFormat = opcode.operandFormat;
	auto ret = getOpcodeStructure!(operandFormat);
	ret.opcode = opcode.opcode;
	ret.encoding = opcode.encoding;
	return ret;
}

unittest
{
	auto opcode = makeOpcode!(Opcodes.Load);
	opcode.register1 = cast(Register)0;
	opcode.register2 = cast(Register)1;
	opcode.register3 = cast(Register)2;

	assert(opcode.opcode == Opcodes.Load.opcode);
	assert(opcode.register1 == cast(Register)0);
	assert(opcode.register2 == cast(Register)1);
	assert(opcode.register3 == cast(Register)2);
}

import std.traits: EnumMembers;
alias OpcodeDescriptorBuffer = OpcodeDescriptor[EnumMembers!(OperandFormat).length];
OpcodeDescriptor[] opcodeToDescriptor(ubyte opcode, OpcodeDescriptorBuffer buffer) @nogc nothrow
{
	import std.traits : EnumMembers;

	size_t index = 0;
	foreach (member; EnumMembers!Opcodes) {
		if (opcode == member.opcode && !member.pseudoOpcode) {
			buffer[index++] = member;
		}
	}

	auto descriptors = buffer[0..index];
	assert(descriptors.length);
	return descriptors;
}

OpcodeDescriptor getDescriptor(Opcode opcode) @nogc nothrow
{
	import std.algorithm : find;
	import std.range : zip, repeat, front;

	OpcodeDescriptorBuffer buffer;
	auto descriptors = opcodeToDescriptor(opcode.a.opcode, buffer);

	return descriptors.find!("a.encoding == b")(opcode.a.encoding).front;
}

char[] disassemble(Opcode opcode, char[] output) @nogc nothrow
{
	import common.cpu : registerName;

	char[16][3] buffers;

	auto descriptor = opcode.getDescriptor();

	string sizePrefix = "";
	if (descriptor.operandFormat.supportsOperandSize)
	{
		import core.stdc.stdio;
		final switch (opcode.a.operandSize)
		{
		case OperandSize.Byte:
			sizePrefix = "byte ";
			break;
		case OperandSize.Byte2:
			sizePrefix = "byte2 ";
			break;
		case OperandSize.Byte4:
			sizePrefix = "word ";
			break;
		}
	}

	string variant;
	final switch (opcode.a.variant)
	{
	case Variant.Identity:
		variant = "";
		break;
	case Variant.ShiftLeft1:
		variant = " << 1";
		break;
	case Variant.ShiftLeft2:
		variant = " << 2";
		break;
	}

	// TODO: Apply metaprogramming to fix this up
	switch (descriptor.operandFormat.name)
	{
	case OperandFormat.DstSrc.name:
		auto encoding = opcode.asEncodingFromOperandFormat!(OperandFormat.DstSrc);
		auto reg1 = encoding.register1.registerName(buffers[0]);
		auto reg2 = encoding.register2.registerName(buffers[1]);

		return "%s %s%s, %s%s".sformat(output, descriptor.name, sizePrefix, reg1, reg2, variant);
	case OperandFormat.DstSrcSrc.name:
		auto encoding = opcode.asEncodingFromOperandFormat!(OperandFormat.DstSrcSrc);
		auto reg1 = encoding.register1.registerName(buffers[0]);
		auto reg2 = encoding.register2.registerName(buffers[1]);
		auto reg3 = encoding.register3.registerName(buffers[2]);

		return "%s %s%s, %s, %s%s".sformat(output, descriptor.name, sizePrefix, reg1, reg2, reg3, variant);
	case OperandFormat.DstUimm.name:
		auto encoding = opcode.asEncodingFromOperandFormat!(OperandFormat.DstUimm);
		auto reg1 = encoding.register1.registerName(buffers[0]);

		return "%s %s, %s%s".sformat(output, descriptor.name, reg1, encoding.immediate, variant);
	case OperandFormat.DstSrcImm.name:
		auto encoding = opcode.asEncodingFromOperandFormat!(OperandFormat.DstSrcImm);
		auto reg1 = encoding.register1.registerName(buffers[0]);
		auto reg2 = encoding.register2.registerName(buffers[1]);

		return "%s %s%s, %s, %s%s".sformat(output, descriptor.name, sizePrefix, reg1, reg2, encoding.immediate, variant);
	case OperandFormat.Label.name:
		auto encoding = opcode.asEncodingFromOperandFormat!(OperandFormat.Label);
		return "%s %s".sformat(output, descriptor.name, encoding.immediate);
	case OperandFormat.None.name:
		return "%s".sformat(output, descriptor.name);
	default:
		assert(0);
	}
}

string disassemble(Opcode opcode)
{
	char[256] buffer;
	return opcode.disassemble(buffer).idup;
}

unittest
{
	auto opcode = makeOpcode!(Opcodes.Load);
	opcode.register1 = cast(Register)0;
	opcode.register2 = cast(Register)1;
	opcode.variant = Variant.ShiftLeft2;

	char[64] buffer;
	auto slice = opcode.disassemble(buffer);

	assert(slice == "load byte r0, r1 << 2");
	assert(opcode.disassemble == slice);
}