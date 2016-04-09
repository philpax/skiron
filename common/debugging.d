module common.debugging;

import common.cpu;
import common.socket;

import std.traits;
import std.range : ElementType;

import core.stdc.stdlib : malloc, free;

enum MessageId : ubyte
{
	Initialize,
	CoreGetState,
	CoreState,
	SystemGetMemory,
	SystemMemory
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

private void serialize(T)(ref ubyte* ptr, T value)
	if (isDynamicArray!T)
{
	ptr.serialize!uint(value.length);

	foreach (ref v; value)
		ptr.serialize(v);

	value = null;
}

private T deserialize(T)(ref ubyte* ptr)
	if (isDynamicArray!T)
{
	alias Element = ElementType!T;
	auto length = ptr.deserialize!uint();
	auto buffer = cast(Element*)malloc(length * Element.sizeof);
	auto ret = buffer[0..length];

	foreach (ref v; ret)
		v = ptr.deserialize!(ElementType!T);

	return ret;
}

private uint serializationLength(T)(T value)
{
	static if (isDynamicArray!T)
		return uint.sizeof + value.length;
	else
		return T.sizeof;
}

mixin template Serializable()
{
@nogc:
nothrow:
	enum Serializable = true;
	enum Id = __traits(getMember, MessageId, typeof(this).stringof);

	~this()
	{
		// Free the memory of arrays that have been deserialised
		foreach (field; getSymbolsByUDA!(typeof(this), Serialize))
		{
			static if (isDynamicArray!(typeof(field)))
				if (field.ptr !is null)
					field.ptr.free();
		}
	}

	ushort length() @property
	{
		ushort ret = ushort.sizeof + MessageId.sizeof;

		foreach (field; getSymbolsByUDA!(typeof(this), Serialize))
			ret += field.serializationLength();

		return ret;
	}

	ubyte[] serialize(ubyte[] targetBuffer)
	{
		auto ptr = targetBuffer.ptr;

		ptr.serialize(cast(ushort)(this.length - ushort.sizeof));
		ptr.serialize(Id);

		foreach (ref field; getSymbolsByUDA!(typeof(this), Serialize))
		{
			ptr.serialize(field);

			static if (isDynamicArray!(typeof(field)))
				field = [];
		}

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

	mixin Serializable;
}

struct CoreGetState
{
	@Serialize uint core;

	mixin Serializable;
}

struct CoreState
{
	@Serialize uint core;
	@Serialize bool running;
	@Serialize RegisterType[RegisterExtendedCount] registers;

	mixin Serializable;
}

struct SystemGetMemory
{
	@Serialize uint begin;
	@Serialize uint end;

	mixin Serializable;
}

struct SystemMemory
{
	@Serialize ubyte[] memory;

	mixin Serializable;
}

enum isSerializableMessage(T) = __traits(compiles, T.Serializable);