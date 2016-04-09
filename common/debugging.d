module common.debugging;

import common.cpu;
public import common.serialization;

enum MessageId : ubyte
{
	Initialize,
	CoreGetState,
	CoreState,
	SystemGetMemory,
	SystemMemory
}

struct Initialize
{
	uint memorySize;
	uint coreCount;
	uint textBegin;
	uint textEnd;

	mixin Serializable!MessageId;
}

struct CoreGetState
{
	uint core;

	mixin Serializable!MessageId;
}

struct CoreState
{
	uint core;
	bool running;
	RegisterType[RegisterExtendedCount] registers;

	mixin Serializable!MessageId;
}

struct SystemGetMemory
{
	uint begin;
	uint end;

	mixin Serializable!MessageId;
}

struct SystemMemory
{
	ubyte[] memory;

	mixin Serializable!MessageId;
}