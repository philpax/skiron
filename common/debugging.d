module common.debugging;

import common.cpu;
public import common.serialization;

enum DebugMessageId : ubyte
{
	Initialize,
	CoreGetState,
	CoreState,
	CoreSetRunning,
	SystemGetMemory,
	SystemMemory
}

struct Initialize
{
	uint memorySize;
	uint coreCount;
	uint textBegin;
	uint textEnd;

	mixin Serializable!DebugMessageId;
}

struct CoreGetState
{
	uint core;

	mixin Serializable!DebugMessageId;
}

struct CoreState
{
	uint core;
	bool running;
	RegisterType[RegisterExtendedCount] registers;

	mixin Serializable!DebugMessageId;
}

struct CoreSetRunning
{
	uint core;
	bool running;

	mixin Serializable!DebugMessageId;
}

struct SystemGetMemory
{
	uint begin;
	uint end;

	mixin Serializable!DebugMessageId;
}

struct SystemMemory
{
	uint address;
	ubyte[] memory;

	mixin Serializable!DebugMessageId;
}