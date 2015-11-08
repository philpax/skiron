import std.stdio;
import std.traits;
import std.file;
import std.string;
import std.conv;
import std.algorithm;

import common.opcode;
import common.cpu;

void main(string[] args)
{
	OpcodeDescriptor[] descriptors;

	foreach (member; EnumMembers!Opcodes)
		descriptors ~= member;

	descriptors.sort!((a,b) 
	{ 
		if (a.opcode < b.opcode) return true;
		if (b.opcode < a.opcode) return false;

		return a.operandFormat == OperandFormat.Pseudo;
	});

	auto file = File("opcodes.md", "w");
	file.writefln("Opcode | Instruction | Operands | Description");
	file.writefln("-------|-------------|----------|------------");

	foreach (descriptor; descriptors)
	{
		if (descriptor.operandFormat != OperandFormat.Pseudo)
			file.writef("`0x%02X`", descriptor.opcode);
		else
			file.writef("Pseudo");
		file.write(" | ");
		file.write('`', descriptor.name, '`');
		file.write(" | ");
		final switch (descriptor.operandFormat)
		{
			case OperandFormat.DstSrc:
				file.write("`dst, src`");
				break;
			case OperandFormat.DstSrcSrc:
				file.write("`dst, src, src`");
				break;
			case OperandFormat.DstImm:
				file.write("`dst, imm`");
				break;
			case OperandFormat.Label:
				file.write("`label`");
				break;
			case OperandFormat.None:
				file.write("");
				break;
			case OperandFormat.Pseudo:
				file.write("");
				break;
		}
		file.write(" | ");
		file.write(descriptor.description);
		file.writeln();
	}
}