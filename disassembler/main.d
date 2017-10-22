import std.stdio;
import std.exception;
import std.traits;
import std.file;
import std.string;
import std.conv;
import std.range;

import common.opcode;
import common.cpu;
import common.util;
import common.program;

void main(string[] args)
{
	enforce(args.length >= 2, "Expected at least one argument");

	Program program;
	auto file = cast(ubyte[])args[1].read();

	if (!file.parseProgram(program))
		return writeln("Failed to parse Skiron program");

	if (program.sections.length)
	{
		writeln("Sections:");

		foreach (section; program.sections)
			writefln("  %s: 0x%X -> 0x%X", section.name, section.begin, section.end);
	}

	writefln("Text: 0x%X -> 0x%X", program.textBegin, program.textEnd);

	OpcodeDescriptor[ubyte] descriptors;

	foreach (member; EnumMembers!Opcodes)
		descriptors[member.opcode] = member;

	writeln("Disassembly:");
	foreach (index, opcode; program.opcodes.enumerate)
	{
		auto address = index * Opcode.sizeof + program.textBegin;
		writefln("  0x%X: %s", address, opcode.disassemble());
	}
}