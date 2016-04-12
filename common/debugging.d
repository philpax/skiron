module common.debugging;

import common.cpu;
public import common.serialization;

mixin("DebugMessageId".generateIdEnum!(common.debugging));

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

struct CoreStep
{
	uint core;	

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

struct Shutdown
{
	mixin Serializable!DebugMessageId;
}