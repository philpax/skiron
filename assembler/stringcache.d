module stringcache;

struct StringCache
{
	public pure nothrow @nogc:

    @disable this();
    @disable this(this);

    /**
	* Params: bucketCount = the initial number of buckets. Must be a
	* power of two
	*/
    this(size_t bucketCount) nothrow @trusted @nogc
		in
		{
			import core.bitop : popcnt;
			static if (size_t.sizeof == 8)
			{
				immutable low = popcnt(cast(uint) bucketCount);
				immutable high = popcnt(cast(uint) (bucketCount >> 32));
				assert ((low == 0 && high == 1) || (low == 1 && high == 0));
			}
			else
			{
				static assert (size_t.sizeof == 4);
				assert (popcnt(cast(uint) bucketCount) == 1);
			}
		}
    body
    {
        buckets = (cast(Node**) calloc((Node*).sizeof, bucketCount))[0 .. bucketCount];
    }

    ~this()
    {
        Block* current = rootBlock;
        while (current !is null)
        {
            Block* prev = current;
            current = current.next;
            free(cast(void*) prev);
        }
        foreach (nodePointer; buckets)
        {
            Node* currentNode = nodePointer;
            while (currentNode !is null)
            {
                if (currentNode.mallocated)
                    free(currentNode.str.ptr);
                Node* prev = currentNode;
                currentNode = currentNode.next;
                free(prev);
            }
        }
        rootBlock = null;
        free(buckets.ptr);
        buckets = null;
    }

    /**
	* Caches a string.
	*/
    string intern(const(ubyte)[] str) @safe
    {
        if (str is null || str.length == 0)
            return "";
        return _intern(str);
    }

    /**
	* ditto
	*/
    string intern(string str) @trusted
    {
        return intern(cast(ubyte[]) str);
    }

    /**
	* The default bucket count for the string cache.
	*/
    static enum defaultBucketCount = 4096;

private:

    string _intern(const(ubyte)[] bytes) @trusted
    {
        immutable uint hash = hashBytes(bytes);
        immutable size_t index = hash & (buckets.length - 1);
        Node* s = find(bytes, hash);
        if (s !is null)
            return cast(string) s.str;
        ubyte[] mem = void;
        bool mallocated = bytes.length > BIG_STRING;
        if (mallocated)
            mem = (cast(ubyte*) malloc(bytes.length))[0 .. bytes.length];
        else
            mem = allocate(bytes.length);
        mem[] = bytes[];
        Node* node = cast(Node*) malloc(Node.sizeof);
        node.str = mem;
        node.hash = hash;
        node.next = buckets[index];
        node.mallocated = mallocated;
        buckets[index] = node;
        return cast(string) mem;
    }

    Node* find(const(ubyte)[] bytes, uint hash) @trusted
    {
        import std.algorithm : equal;
        immutable size_t index = hash & (buckets.length - 1);
        Node* node = buckets[index];
        while (node !is null)
        {
            if (node.hash == hash && bytes == cast(ubyte[]) node.str)
                return node;
            node = node.next;
        }
        return node;
    }

    static uint hashBytes(const(ubyte)[] data) pure nothrow @trusted @nogc
		in
		{
			assert (data !is null);
			assert (data.length > 0);
		}
    body
    {
        immutable uint m = 0x5bd1e995;
        immutable int r = 24;
        uint h = cast(uint) data.length;
        while (data.length >= 4)
        {
            uint k = (cast(ubyte) data[3]) << 24
                | (cast(ubyte) data[2]) << 16
                | (cast(ubyte) data[1]) << 8
                | (cast(ubyte) data[0]);
            k *= m;
            k ^= k >> r;
            k *= m;
            h *= m;
            h ^= k;
            data = data[4 .. $];
        }
        switch (data.length & 3)
        {
			case 3:
				h ^= data[2] << 16;
				goto case;
			case 2:
				h ^= data[1] << 8;
				goto case;
			case 1:
				h ^= data[0];
				h *= m;
				break;
			default:
				break;
        }
        h ^= h >> 13;
        h *= m;
        h ^= h >> 15;
        return h;
    }

    ubyte[] allocate(size_t numBytes) pure nothrow @trusted @nogc
		in
		{
			assert (numBytes != 0);
		}
    out (result)
    {
        assert (result.length == numBytes);
    }
    body
    {
        Block* r = rootBlock;
        size_t i = 0;
        while  (i <= 3 && r !is null)
        {
            immutable size_t available = r.bytes.length;
            immutable size_t oldUsed = r.used;
            immutable size_t newUsed = oldUsed + numBytes;
            if (newUsed <= available)
            {
                r.used = newUsed;
                return r.bytes[oldUsed .. newUsed];
            }
            i++;
            r = r.next;
        }
        Block* b = cast(Block*) calloc(Block.sizeof, 1);
        b.used = numBytes;
        b.next = rootBlock;
        rootBlock = b;
        return b.bytes[0 .. numBytes];
    }

    static struct Node
    {
        ubyte[] str = void;
        Node* next = void;
        uint hash = void;
        bool mallocated = void;
    }

    static struct Block
    {
        Block* next;
        size_t used;
        enum BLOCK_CAPACITY = BLOCK_SIZE - size_t.sizeof - (void*).sizeof;
        ubyte[BLOCK_CAPACITY] bytes;
    }

    static assert (BLOCK_SIZE == Block.sizeof);

    enum BLOCK_SIZE = 1024 * 16;

    // If a string would take up more than 1/4 of a block, allocate it outside
    // of the block.
    enum BIG_STRING = BLOCK_SIZE / 4;

    Node*[] buckets;
    Block* rootBlock;
}

private extern(C) void* calloc(size_t, size_t) nothrow pure @nogc @trusted;
private extern(C) void* malloc(size_t) nothrow pure @nogc @trusted;
private extern(C) void free(void*) nothrow pure @nogc @trusted;