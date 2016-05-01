module emulator.device.device;

enum AccessMode
{
	Read,
	Write,
	ReadWrite
}

struct MemoryMap
{
	uint offset;
	AccessMode accessMode;
}

class Device
{
@nogc:
nothrow:
	uint address;
	
	this(uint address)
	{
		this.address = address;
	}

	uint mapSize() @property const
	{
		return 0;
	}
	
	alias mapBegin = address;

	final uint mapEnd() @property const
	{
		return this.mapBegin + this.mapSize;
	}

	final bool isAddressMapped(uint address) const
	{
		return address >= this.mapBegin && address <= this.mapEnd;
	}

	void* map(uint address)
	{
		return null;
	}
}

enum StringOf(alias a) = a.stringof;
mixin template DeviceImpl()
{
	import std.traits : getSymbolsByUDA, getUDAs, isDynamicArray, Identity;
	import std.meta : staticMap;

	final size_t getSize(T)(T value) const
	{
		static if (is(T U : U[]))
			return U.sizeof * value.length;
		else
			return T.sizeof;
	}

	override uint mapSize() @property const
	{
		uint ret;
		foreach (symbol; getSymbolsByUDA!(typeof(this), MemoryMap))
			ret += this.getSize(symbol);

		return ret;
	}

	override void* map(uint address)
	{
		auto offset = address - this.mapBegin;

		enum symbolStrings = staticMap!(StringOf, getSymbolsByUDA!(typeof(this), MemoryMap));
		foreach (fieldName; symbolStrings)
		{
			alias field = Identity!(__traits(getMember, this, fieldName));
			enum memoryMap = getUDAs!(field, MemoryMap)[0];
			auto fieldMapBegin = memoryMap.offset;
			auto fieldMapEnd = fieldMapBegin + this.getSize(field);

			auto offsetFromField = offset - fieldMapBegin;

			if (offset >= fieldMapBegin && offset <= fieldMapEnd)
			{
				static if (isDynamicArray!(typeof(field)))
					return cast(ubyte*)field.ptr + offsetFromField;
				else
					return cast(ubyte*)&field + offsetFromField;
			}
		}
		return null;
	}
}