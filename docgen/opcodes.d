module docgen.opcodes;

import std.stdio;
import std.algorithm;
import std.array;
import std.string;
import std.uni;

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
		(a, b) => !a.pseudoOpcode && b.pseudoOpcode,
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

		file.writef("## %s ", descriptor.name);
		final switch (descriptor.operandFormat.name)
		{
		case OperandFormat.DstSrc.name:
			file.write("dst, src");
			break;
		case OperandFormat.DstSrcSrc.name:
			file.write("dst, src, src");
			break;
		case OperandFormat.DstUimm.name:
			file.write("dst, uimm");
			break;
		case OperandFormat.DstSrcImm.name:
			file.write("dst, src, imm");
			break;
		case OperandFormat.Label.name:
			file.write("label");
			break;
		case OperandFormat.None.name:
			break;
		case OperandFormat.Uimm.name:
			file.write("uimm");
			break;
		case OperandFormat.Dst.name:
			file.write("dst");
			break;
		}
		file.writeln();

		file.writeln(descriptor.description);
		file.writeln();
		file.write("* *Opcode*: ");

		if (!descriptor.pseudoOpcode)
			file.writefln("`0x%02X`", descriptor.opcode);
		else
			file.writefln("Pseudo");

		file.write("* *Operand Format*: ");
		string[] components;
		foreach (c; descriptor.operandFormat.name)
		{
			if (c.isUpper)
				components ~= [c];
			else
				components[$-1] ~= c;
		}
		auto operandFormat = components.map!((a)
		{
			switch (a)
			{
			case "Dst":
				return "destination";
			case "Src":
				return "source";
			case "Uimm":
				return "unsigned immediate";
			case "Imm":
				return "immediate";
			default:
				return a.toLower();
			}
		}).join(", ").capitalize();
		file.writefln("%s (`%s`)", operandFormat, descriptor.operandFormat.name);
		file.writeln();
	}

	return filename;
}