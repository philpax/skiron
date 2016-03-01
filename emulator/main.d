import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;

import std.exception;

import common.opcode;
import common.util;

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

	auto memory = malloc(fileSize);
	scope (exit) free(memory);
	fread(memory, fileSize, 1, file);

	if ((cast(uint*)memory)[0] != HeaderMagicCode)
	{
		printf("Invalid header code");
		return;
	}

	auto dataPtr = memory + uint.sizeof;
	auto dataSize = fileSize - uint.sizeof;
	auto state = State(1024 * 1024, 1);
	memcpy(state.memory.ptr, dataPtr, dataSize);

	state.run();
}