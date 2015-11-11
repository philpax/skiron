import std.stdio;
import std.exception;
import std.traits;
import std.file;
import std.string;
import std.conv;
import std.range;

import common.opcode;
import common.cpu;

void main(string[] args)
{
	enforce(args.length >= 2, "Expected at least one argument");
	auto opcodes = cast(Opcode[])std.file.read(args[1]);

	OpcodeDescriptor[ubyte] descriptors;

	foreach (member; EnumMembers!Opcodes)
		descriptors[member.opcode] = member;

	char[64] buffer;
	foreach (index, opcode; opcodes.enumerate)
	{
		auto inst = opcode.disassemble(buffer);
		writefln("%X: %s", index * Opcode.sizeof, inst);
	}
}