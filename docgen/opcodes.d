module docgen.opcodes;

import std.stdio;

import common.opcode;
import common.encoding;
import common.cpu;

OpcodeDescriptor[] getDescriptors()
{
	import std.traits : EnumMembers;
	import std.algorithm : sort;
	OpcodeDescriptor[] descriptors;

	foreach (member; EnumMembers!Opcodes)
		descriptors ~= member;

	descriptors.sort!((a,b) 
	{ 
		if (a.operandFormat != OperandFormat.Pseudo && 
			b.operandFormat != OperandFormat.Pseudo)
		{
			if (a.opcode < b.opcode) return true;
			if (b.opcode < a.opcode) return false;
		}

		if (a.operandFormat == OperandFormat.Pseudo && 
			b.operandFormat != OperandFormat.Pseudo)
			return false;

		if (b.operandFormat == OperandFormat.Pseudo && 
			a.operandFormat != OperandFormat.Pseudo)
			return true;

		return a.name < b.name;
	});

	return descriptors;
}

string writeOpcodes()
{
	import std.range : enumerate;

	const filename = "Instruction-Listing.md";
	auto file = File(filename, "w");

	auto descriptors = getDescriptors();
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
			switch (descriptor.operandFormat)
			{
			case OperandFormat.DstSrc:
				file.writeln("`dst, src`");
				break;
			case OperandFormat.DstSrcSrc:
				file.writeln("`dst, src, src`");
				break;
			case OperandFormat.DstUImm:
				file.writeln("`dst, imm`");
				break;
			case OperandFormat.DstSrcImm:
				file.writeln("`dst, src, imm`");
				break;
			case OperandFormat.Label:
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