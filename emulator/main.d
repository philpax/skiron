import std.file;
import std.path;
import std.stdio;

import common.util;

import emulator.state;

void runEmulator(ubyte[] program) @nogc nothrow
{
	printf("Skiron Emulator\n");
	auto state = State(1024 * 1024, 1);
	state.memory[0 .. program.length] = program;
	state.run();
}

void main(string[] args)
{
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

	program = program[uint.sizeof .. $];
	program.runEmulator();
}