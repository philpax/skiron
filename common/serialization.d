module common.serialization;

import common.socket;

import std.traits;
import std.range : ElementType;

import core.stdc.stdlib : malloc, free;

string generateIdEnum(alias Module)(string name)
{
	string s = "enum " ~ name ~ " : ubyte {";
	foreach (member; __traits(allMembers, Module))
	{
		// WORKAROUND: Issue 15907
		static if (member != "object" && member != "common")
		{
			alias memberField = Identity!(__traits(getMember, Module, member));
		
			static if (is(memberField == struct))
				s ~= member ~ ",\n";
		}
	}
	s ~= "}";
	return s;
}

mixin template GenerateIdEnum(string name)
{
	mixin(generateIdEnum!(__traits(parent, {}))(name));
}

@nogc:
nothrow:

void serialize(T)(ref ubyte* ptr, T value)
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

T deserialize(T)(ref ubyte* ptr)
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

void serialize(T)(ref ubyte* ptr, T value)
	if (isDynamicArray!T)
{
	ptr.serialize!uint(value.length);

	foreach (ref v; value)
		ptr.serialize(v);

	value = null;
}

T deserialize(T)(ref ubyte* ptr)
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

uint serializationLength(T)(T value)
{
	static if (is(T U : U[]))
		return uint.sizeof + U.sizeof * value.length;
	else
		return T.sizeof;
}

mixin template Serializable(MessageId)
{
@nogc:
nothrow:
	import std.traits;

	enum Serializable = true;
	enum Id = __traits(getMember, MessageId, typeof(this).stringof);

	~this()
	{
		import core.stdc.stdlib : free;

		// Free the memory of arrays that have been deserialised
		foreach (field; this.tupleof)
		{
			static if (isDynamicArray!(typeof(field)))
				if (field.ptr !is null)
					field.ptr.free();
		}
	}

	ushort length() @property
	{
		ushort ret = ushort.sizeof + MessageId.sizeof;

		foreach (field; this.tupleof)
			ret += field.serializationLength();

		return ret;
	}

	ubyte[] serialize(ubyte[] targetBuffer)
	{
		auto ptr = targetBuffer.ptr;

		ptr.serialize(cast(ushort)(this.length - ushort.sizeof));
		ptr.serialize(Id);

		foreach (ref field; this.tupleof)
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

		foreach (ref field; this.tupleof)
			field = ptr.deserialize!(typeof(field));
	}
}

T deserializeMessage(T)(ubyte[] buffer)
{
	T ret;
	ret.deserialize(buffer);
	return ret;
}

enum isSerializableMessage(T) = __traits(compiles, T.Serializable);