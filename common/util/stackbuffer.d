module common.util.stackbuffer;

struct StackBuffer(uint Size)
{
@nogc:
nothrow:
	private union {
		ubyte[Size] buffer;
		ubyte* bufferPtr;
	}
	private size_t length_;

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

		this.length_ = size;
		if (size > Size)
			this.bufferPtr = cast(ubyte*)malloc(size);
	}

	ubyte[] data() @property
	{
		return this.length > Size ? this.bufferPtr[0..this.length] : this.buffer;
	}

	size_t length() @property const
	{
		return this.length_;
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