import core.memory;

import std.file;
import std.path;
import std.stdio;
import std.process;
import std.getopt;

import common.util;

import emulator.state;

void runEmulator(ubyte[] program, bool printOpcodes, bool printRegisters) @nogc nothrow
{
	printf("Skiron Emulator\n");
	auto state = State(1024 * 1024, 1, printOpcodes, printRegisters);
	state.load(program);
	state.run();
}

void main(string[] args)
{
	bool printOpcodes = false;
	bool printRegisters = false;
	args.getopt(
		"print-opcodes", &printOpcodes, 
		"print-registers", &printRegisters);

	if (args.length < 2)
	{
		writeln("emulator filename");
		return;
	}

	auto filePath = args[1];
	if (!filePath.exists())
	{
		writefln("File '%s' does not exist", filePath);
		return;
	}

	if (filePath.extension() == ".skasm")
	{
		writefln("Assembling '%s'", filePath);
		auto assembler = ["assembler", filePath].execute();

		if (assembler.status != 0)
		{
			writefln("Failed to assemble '%s'", filePath);
			writefln("Assembler output: %s", assembler.output);
			return;
		}
		else
		{
			writefln("Successfully assembled '%s'", filePath);
		}

		filePath = filePath.setExtension(".bin");
	}

	auto program = cast(ubyte[])filePath.read();
	if (program.length < 4)
	{
		writefln("File '%s' too small", filePath);
		return;
	}

	if ((cast(uint*)program.ptr)[0] != HeaderMagicCode)
	{
		writefln("Expected file '%s' to start with Skiron header", filePath);
		return;
	}

	GC.collect();
	GC.disable();

	program = program[uint.sizeof .. $];
	program.runEmulator(printOpcodes, printRegisters);
}