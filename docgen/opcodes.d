module docgen.opcodes;

import std.stdio;

import common.opcode;
import common.encoding;
import common.cpu;

string writeOpcodes()
{
	import std.range : enumerate;
	import std.traits : EnumMembers;
	import std.algorithm : multiSort;

	const filename = "Instruction-Listing.md";
	auto file = File(filename, "w");

	auto descriptors = [EnumMembers!Opcodes];
	descriptors.multiSort!(
		(a, b) => a.operandFormat != OperandFormat.Pseudo && b.operandFormat == OperandFormat.Pseudo,
		(a, b) => a.opcode < b.opcode,
		(a, b) => a.name < b.name);

	foreach (index, descriptor; descriptors.enumerate)
	{
		if (index > 0)
		{
			auto prevDescriptor = descriptors[index-1];
			auto diff = descriptor.opcode - prevDescriptor.opcode;

			if (diff == 2)
				file.writeln("## Unallocated opcode");
			else if (diff > 2)
				file.writefln("## Unallocated opcodes (%s free)", diff -  1);

			if (diff > 1)
				file.writeln();
		}

		file.writefln("## %s", descriptor.name);
		file.writeln(descriptor.description);
		file.writeln();
		file.write("* *Opcode*: ");

		if (descriptor.operandFormat != OperandFormat.Pseudo)
			file.writefln("`0x%02X`", descriptor.opcode);
		else
			file.writefln("Pseudo");

		if (descriptor.operandFormat != OperandFormat.None && 
			descriptor.operandFormat != OperandFormat.Pseudo)
		{
			file.write("* *Operand Format*: ");
			switch (descriptor.operandFormat.name)
			{
			case OperandFormat.DstSrc.name:
				file.writeln("`dst, src`");
				break;
			case OperandFormat.DstSrcSrc.name:
				file.writeln("`dst, src, src`");
				break;
			case OperandFormat.DstUImm.name:
				file.writeln("`dst, imm`");
				break;
			case OperandFormat.DstSrcImm.name:
				file.writeln("`dst, src, imm`");
				break;
			case OperandFormat.Label.name:
				file.writeln("`label`");
				break;
			default:
				assert(0);
			}
		}
		
		file.writeln();
	}

	return filename;
}