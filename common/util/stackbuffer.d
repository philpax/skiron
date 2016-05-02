module common.util.stackbuffer;

struct StackBuffer(uint Size)
{
	private union {
		ubyte[Size] buffer;
		ubyte* bufferPtr;
	}
	private uint length;

	this(uint size)
	{
		this.allocate(size);
	}

	~this()
	{
		import core.stdc.stdlib : free;

		if (this.length > Size)
			free(this.bufferPtr);
	}

	void allocate(uint size)
	{
		import core.stdc.stdlib : malloc;

		this.length = size;
		if (size > Size)
			this.bufferPtr = cast(ubyte*)malloc(size);
	}

	ubyte[] data() @property
	{
		return this.length > Size ? this.bufferPtr[0..this.length] : this.buffer;
	}

	alias data this;
}

unittest
{
	StackBuffer!16 buf;
	buf.allocate(8);
	assert(buf.data.ptr == buf.buffer.ptr);
	buf.allocate(32);
	assert(buf.data.ptr == buf.bufferPtr);
}