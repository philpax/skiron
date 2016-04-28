module emulator.screen;

import emulator.device;

import core.stdc.stdlib;

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