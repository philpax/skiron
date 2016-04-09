module common.debugging;

import common.cpu;
import common.socket;

import std.traits;

enum MessageId : ubyte
{
	Initialize,
	CoreGetState,
	CoreState
}

enum Serialize;

@nogc:
nothrow:

private void serialize(T)(ref ubyte* ptr, T value)
	if (isScalarType!T || isStaticArray!T)
{
	import core.stdc.string : memcpy;

	static if (is(T == ushort))
		value = value.htons();
	else static if (is(T == uint))
		value = value.htonl();

	memcpy(ptr, &value, T.sizeof);
	ptr += T.sizeof;
}

private T deserialize(T)(ref ubyte* ptr)
	if (isScalarType!T || isStaticArray!T)
{
	import core.stdc.string : memcpy;

	T value;
	memcpy(&value, ptr, T.sizeof);
	ptr += T.sizeof;

	static if (is(T == ushort))
		value = value.ntohs();
	else static if (is(T == uint))
		value = value.ntohl();

	return value;
}

mixin template Serializable(MessageId messageId)
{
@nogc:
nothrow:
	ushort length() @property
	{
		ushort ret = ushort.sizeof + MessageId.sizeof;

		foreach (field; getSymbolsByUDA!(typeof(this), Serialize))
			ret += typeof(field).sizeof;

		return ret;
	}

	ubyte[] serialize(ubyte[] targetBuffer)
	{
		auto ptr = targetBuffer.ptr;

		ptr.serialize!ushort(this.length);
		ptr.serialize(messageId);

		foreach (field; getSymbolsByUDA!(typeof(this), Serialize))
			ptr.serialize(field);

		return targetBuffer;
	}

	void deserialize(ubyte[] targetBuffer)
	{
		auto ptr = targetBuffer.ptr;

		ptr.deserialize!MessageId();

		foreach (ref field; getSymbolsByUDA!(typeof(this), Serialize))
			field = ptr.deserialize!(typeof(field));
	}
}

struct Initialize
{
	@Serialize uint memorySize;
	@Serialize uint coreCount;
	@Serialize uint textBegin;
	@Serialize uint textEnd;

	mixin Serializable!(MessageId.Initialize);
}

struct CoreGetState
{
	@Serialize uint core;

	mixin Serializable!(MessageId.CoreGetState);
}

struct CoreState
{
	@Serialize uint core;
	@Serialize bool running;
	@Serialize RegisterType[RegisterExtendedCount] registers;

	mixin Serializable!(MessageId.CoreState);
}