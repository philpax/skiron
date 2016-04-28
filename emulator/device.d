module emulator.device;

enum AccessMode
{
	Read,
	Write,
	ReadWrite
}

struct MemoryMap
{
	AccessMode accessMode;
}

mixin template Device()
{
	import std.traits : getSymbolsByUDA, isDynamicArray;

	uint address;

	uint mapSize() @property const
	{
		uint ret;
		foreach (symbol; getSymbolsByUDA!(typeof(this), MemoryMap))
		{
			alias T = typeof(symbol);

			static if (is(T U : U[]))
				ret += U.sizeof * symbol.length;
			else
				ret += T.sizeof;
		}

		return ret;
	}

	uint mapBegin() @property const
	{
		return this.address;
	}

	uint mapEnd() @property const
	{
		return this.mapBegin + this.mapSize;
	}

	bool isAddressMapped(uint address)
	{
		return address >= this.mapBegin && address <= this.mapEnd;
	}

	void* translateOffset(size_t offset)
	{
		alias MappedSymbols = getSymbolsByUDA!(typeof(this), MemoryMap);

		// Terrible heuristic! Improve later
		alias LastElement = MappedSymbols[$-1];
		if (isDynamicArray!(typeof(LastElement)) && offset >= LastElement.offsetof)
		{
			static if (is(typeof(LastElement) U : U[]))
				return cast(void*)(cast(ubyte*)LastElement.ptr + (offset - LastElement.offsetof));
			else
				static assert(false);
		}
		else
		{
			return cast(void*)(cast(ubyte*)&this + offset);
		}
	}

	void* translateAddress(uint address)
	{
		return this.translateOffset(address - this.mapBegin);
	}

	T get(T)(uint address)
	{
		return *cast(T*)this.translateAddress(address);
	}

	void set(T)(uint address, T value)
	{
		*cast(T*)this.translateAddress(address) = value;
	}
}