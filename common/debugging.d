module common.debugging;

import common.cpu;

import std.traits, std.meta, std.algorithm;

enum MessageId : ubyte
{
	Initialize
}

enum Serialize;

private string generateSerializationLength(T)()
{
	import std.string : format;

	size_t length = MessageId.sizeof;
	foreach (fieldName; __traits(allMembers, T))
	{
		alias field = Identity!(__traits(getMember, T, fieldName));

		static if (hasUDA!(field, Serialize))
			length += typeof(field).sizeof;
	}

	return "enum Length = %s;\n".format(length);
}

private void serialize(T)(ref ubyte* ptr, T value)
{
	import core.stdc.string : memcpy;

	memcpy(ptr, &value, T.sizeof);
	ptr += T.sizeof;
}

private T deserialize(T)(ref ubyte* ptr)
{
	import core.stdc.string : memcpy;

	T value;
	memcpy(&value, ptr, T.sizeof);
	ptr += T.sizeof;
	return value;
}

mixin template Serializable(MessageId messageId)
{
	mixin(generateSerializationLength!(typeof(this)));

	ubyte[] serialize(ubyte[] targetBuffer)
	{
		auto ptr = targetBuffer.ptr;

		ptr.serialize!ushort(Length);
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
@nogc:
nothrow:
	@Serialize uint memorySize;
	@Serialize uint coreCount;

	mixin Serializable!(MessageId.Initialize);
}