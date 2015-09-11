import std.stdio;
import std.exception;
import std.traits;
import std.file;
import std.string;
import std.conv;

import common.opcode;
import common.cpu;

string registerName(ubyte index)
{
	if (index == Register.IP)
		return "ip";
	else if (index == Register.SP)
		return "sp";
	else if (index == Register.BP)
		return "bp";
	else if (index == Register.Z)
		return "z";
	else
		return "r%s".format(index);
}

void main(string[] args)
{
	enforce(args.length >= 2, "Expected at least one argument");
	auto opcodes = cast(Opcode[])std.file.read(args[1]);

	OpcodeDescriptor[ubyte] descriptors;

	foreach (member; EnumMembers!Opcodes)
		descriptors[member.opcode] = member;

	foreach (opcode; opcodes)
	{
		auto descriptor = opcode.opcode in descriptors;
		enforce(descriptor, "No matching opcode found");

		write(descriptor.name, ' ');

		if (descriptor.operandFormat == OperandFormat.DstSrc)
		{
			write(opcode.register1.registerName());
			write(", ");
			write(opcode.register2.registerName());
		}
		else if (descriptor.operandFormat == OperandFormat.DstSrcSrc)
		{
			write(opcode.register1.registerName());
			write(", ");
			write(opcode.register2.registerName());
			write(", ");
			write(opcode.register3.registerName());
		}
		else if (descriptor.operandFormat == OperandFormat.DstImm)
		{
			write(opcode.register1.registerName());
			write(", ");
			write(opcode.immediate.to!string());
		}
		else
		{
			assert(0);
		}

		writeln();
	}
}