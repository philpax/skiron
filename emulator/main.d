import core.memory;

import std.file;
import std.path;
import std.stdio;
import std.getopt;

import common.util;

import emulator.state;

void runEmulator(ubyte[] program, const ref Config config) @nogc nothrow
{
	printf("Skiron Emulator\n");
	auto state = State(config);
	state.load(program);
	state.run();
}

void main(string[] args)
{
	Config config;
	args.getopt(
		"print-opcodes", &config.printOpcodes, 
		"print-registers", &config.printRegisters,
		"paused", &config.paused,
		"memory-size", &config.memorySize,
		"core-count", &config.coreCount,
		"port", &config.port);

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
		import std.process : execute;
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
	program.runEmulator(config);
}