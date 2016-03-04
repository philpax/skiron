import core.stdc.stdio;
import core.stdc.string;
import core.stdc.stdlib;

import std.exception;
import std.internal.cstring;

import common.opcode;
import common.util;

import emulator.state;

@nogc:
nothrow:

void main(string[] args) @nogc
{
	if (args.length < 2)
	{
		printf("emulator filename\n");
		return;
	}

	printf("Skiron Emulator\n");

	auto filePath = args[1].tempCString();
	auto file = fopen(filePath, "rb");

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