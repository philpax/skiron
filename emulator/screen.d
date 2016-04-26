module emulator.screen;

import core.stdc.stdlib;

enum AccessMode
{
	Read,
	Write,
	ReadWrite
}

union Pixel
{
	struct
	{
		ubyte r;
		ubyte g;
		ubyte b;
	}

	ubyte[3] data;
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

struct Screen
{
@nogc:
nothrow:
	@MemoryMap(AccessMode.Read)
	uint width;

	@MemoryMap(AccessMode.Read)
	uint height;

	@MemoryMap(AccessMode.ReadWrite)
	Pixel[] pixels;

	this(uint address, uint width, uint height)
	{
		this.address = address;
		this.width = width;
		this.height = height;

		auto count = width * height;
		this.pixels = (cast(Pixel*).malloc(count * Pixel.sizeof))[0..count];
	}

	~this()
	{
		.free(this.pixels.ptr);
	}

	mixin Device;
}