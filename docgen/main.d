import std.stdio;
import std.traits;
import std.file;
import std.string;
import std.conv;
import std.algorithm;
import std.range;
import std.meta;

import common.opcode;
import common.cpu;

void writeOpcodes()
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

	auto file = File("opcodes.md", "w");
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
}

void writeEncodings()
{
	auto file = File("encodings.md", "w");

	string[string] fieldDescriptions;
	string getFormattedFields(Args...)()
	{
		static if (Args.length)
		{
			auto fieldName = Args[1];
			auto description = Args[3];

			if (fieldName !in fieldDescriptions)
				fieldDescriptions[fieldName] = description;
			else if (description.empty)
				description = fieldDescriptions[fieldName];

			auto ret = "* `%s` (`%s`, %s bytes)".format(fieldName, Args[0].stringof, Args[2]);

			if (description.length)
				ret ~= ": %s".format(description);

			ret ~= '\n';
			ret ~= getFormattedFields!(Args[4..$]);
			return ret;
		}
		else
		{
			return "";
		}
	}

	
	enum prefix = "EncodingSeq";
	enum isEncodingSeq(string String) = String.startsWith(prefix);

	foreach (encodingSeqName; Filter!(isEncodingSeq, __traits(allMembers, Opcode)))
	{
		alias field = AliasSeq!(__traits(getMember, Opcode, encodingSeqName));
		auto encodingName = encodingSeqName[prefix.length .. $];

		file.writefln("## Encoding %s", encodingName);
		file.writeln(field[0]);
		file.writeln();
		file.write(getFormattedFields!(field[1..$]));
		file.writeln();
	}
}

void main(string[] args)
{
	writeOpcodes();
	writeEncodings();
}