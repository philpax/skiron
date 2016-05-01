module docgen.registers;

import std.stdio;
import std.string : toLower;
import std.conv : to;
import std.algorithm : filter;

import common.opcode;
import common.encoding;
import common.cpu;

void writeRegistersDescription(ref File file)
{
	file.writeln("# Registers");
	file.writefln(
		"As Skiron is a RISC-inspired architecture, a high register count is one " ~
		"of its design goals. To wit, it has %s general registers, with %s extended " ~
		"(not directly accessible) register(s). However, the upper %s registers are " ~
		"reserved for use with specific instructions and/or CPU operation; while they " ~
		"can be accessed, they are not guaranteed to operate the same way as regular " ~
		"registers.",
		RegisterCount, RegisterExtendedCount - RegisterCount, RegisterCount - RegisterGeneralCount);

	file.writeln();
}

void writeStandardRegisters(ref File file)
{
	file.writeln("## Standard Registers");
	file.writeln(
		"The standard registers have specific behaviours associated with them. " ~
		"These behaviours can be found in the description for each register. ");
	file.writeln();

	foreach (key, value; RegisterDocs.filter!(a => a[0] < RegisterCount))
	{
		file.writefln("* **%s**", key.to!string.toLower());
		file.writefln("    * *Index*: %s", cast(uint)key);
		file.writefln("    * *Description*: %s", value);
	}

	file.writeln();
}

void writeExtendedRegisters(ref File file)
{
	import std.math : log2;
	import std.traits : EnumMembers;

	file.writeln("## Extended Registers");
	file.writeln(
		"The extended registers are not directly accessible through normal means. " ~
		"They are typically used for information exclusive to the CPU, such as " ~
		"the value of the last conditional comparison (`cmp`) undertaken.");
	file.writeln();

	foreach (key, value; RegisterDocs.filter!(a => a[0] >= RegisterCount))
	{
		file.writefln("* **%s**", key.to!string.toLower());
		file.writefln("    * *Index*: %s", cast(uint)key);
		file.writefln("    * *Description*: %s", value);

		if (key == Register.Flags)
		{
			file.writeln("    * *Values:*");
			foreach (member; EnumMembers!Flags)
			{
				auto number = member.to!uint();
				if (number == 0)
					file.writefln("        * %s: %s", member, number);
				else
					file.writefln("        * %s: 1 << %s", member, number.log2());
			}
		}
	}
}

string writeRegisters()
{
	const filename = "Registers.md";
	auto file = File(filename, "w");

	file.writeRegistersDescription();
	file.writeStandardRegisters();
	file.writeExtendedRegisters();

	return filename;
}