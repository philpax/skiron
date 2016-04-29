module emulator.screen;

public import emulator.device;

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

class Screen : Device
{
@nogc:
nothrow:
	@MemoryMap(0, AccessMode.Read)
	uint width;

	@MemoryMap(4, AccessMode.Read)
	uint height;

	@MemoryMap(8, AccessMode.ReadWrite)
	Pixel[] pixels;

	this(uint address, uint width, uint height)
	{
		super(address);
		this.width = width;
		this.height = height;

		auto count = width * height;
		this.pixels = (cast(Pixel*).malloc(count * Pixel.sizeof))[0..count];
	}

	~this()
	{
		.free(this.pixels.ptr);
	}

	mixin DeviceImpl;
}