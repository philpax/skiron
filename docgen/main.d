import std.stdio;
import std.traits;
import std.file;
import std.string;
import std.conv;
import std.algorithm;
import std.range;
import std.meta;
import std.path;

import common.opcode;
import common.cpu;

string writeOpcodes()
{
	OpcodeDescriptor[] descriptors;

	foreach (member; EnumMembers!Opcodes)
		descriptors ~= member;

	descriptors.sort!((a,b) 
	{ 
		if (a.opcode < b.opcode) return true;
		if (b.opcode < a.opcode) return false;

		return a.operandFormat == OperandFormat.Pseudo && 
				b.operandFormat != OperandFormat.Pseudo;
	});

	const filename = "Instruction-Listing.md";
	auto file = File(filename, "w");
	file.writefln("Opcode | Instruction | Operands | Description");
	file.writefln("-------|-------------|----------|------------");

	foreach (index, descriptor; descriptors.enumerate)
	{
		if (index > 0)
		{
			auto prevDescriptor = descriptors[index-1];
			auto diff = descriptor.opcode - prevDescriptor.opcode;

			if (diff == 2)
			{
				file.writefln("`0x%02X` | | | Unallocated opcode", descriptor.opcode - 1);
			}
			else if (diff > 2)
			{
				file.writefln("`0x%02X - 0x%02X` | | | Unallocated opcodes (%s free)",
					prevDescriptor.opcode + 1, descriptor.opcode - 1, diff -  1);
			}
		}

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
			case OperandFormat.DstSrcImm:
				file.write("`dst, src, imm`");
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

	return filename;
}

string writeEncodings()
{
	const filename = "Opcode-Encoding.md";
	auto file = File(filename, "w");

	enum prefix = "EncodingSeq";
	enum isEncodingSeq(string String) = String.startsWith(prefix);

	string[string] fieldDescriptions;
	foreach (encodingSeqName; Filter!(isEncodingSeq, __traits(allMembers, Opcode)))
	{
		auto encodingDescription = __traits(getMember, Opcode, encodingSeqName);

		file.writefln("## Encoding %s", encodingDescription.name);
		file.writeln(encodingDescription.description);
		file.writeln();

		file.writeln("### Field Layout");
		file.writeln(encodingDescription.fields.map!(a => "%s bits".format(a.size)).join(" | "));
		file.writeln(encodingDescription.fields.map!(a => "---").join(" | "));
		file.writeln(encodingDescription.fields.map!(a => '`' ~ a.name ~ '`').join(" | "));
		file.writeln();

		foreach (field; encodingDescription.fields)
		{
			auto description = field.description;

			if (field.name !in fieldDescriptions)
				fieldDescriptions[field.name] = description;
			else if (description.empty)
				description = fieldDescriptions[field.name];

			file.writef("* `%s` (`%s`, %s bits)", field.name, field.type, field.size);

			if (description.length)
				file.writef(": %s", description);

			file.writeln();
		}

		file.writeln();
	}

	return filename;
}

void main(string[] args)
{
	auto files = [writeOpcodes(), writeEncodings()];

	const wikiPath = "../skiron.wiki";
	if (wikiPath.exists && wikiPath.isDir)
	{
		foreach (file; files)
			std.file.copy(file, wikiPath.buildPath(file));
	}
}