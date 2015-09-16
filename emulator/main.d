import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;

import std.exception;

import common.opcode;

import emulator.state;

@nogc:
nothrow:

void main(string[] args)
{
	if (args.length < 2)
	{
		printf("emulator filename\n");
		return;
	}

	printf("Skiron Emulator\n");

	// Temporary workaround until Runtime.cArgs is @nogc
	auto filePath = args[1];
	auto cString = cast(char*)alloca(filePath.length + 1);
	memcpy(cString, filePath.ptr, filePath.length);
	cString[filePath.length] = '\0';

	auto file = fopen(cString, "rb");

	if (file == null)
	{
		printf("Failed to open file: %s\n", args[1].ptr);
		return;
	}

	scope (exit) fclose(file);

	fseek(file, 0, SEEK_END);
	auto fileSize = ftell(file);
	fseek(file, 0, SEEK_SET);

	auto state = State(1024 * 1024, 4);
	fread(state.memory.ptr, fileSize, 1, file);

	state.run();
}