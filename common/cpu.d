module common.cpu;

enum RegisterCount = (1 << 7);
enum Register
{
	// Zero register (always 0)
	Z = RegisterCount-4,
	// Stack base pointer
	BP = RegisterCount-3,
	// Stack top pointer
	SP = RegisterCount-2,
	// Instruction pointer
	IP = RegisterCount-1,
	// Flags
	Flags = RegisterCount
}

enum Flags
{
	None,
	Zero = 1 << 0,
	Greater = 1 << 1,
	Less = 1 << 2
}

char[] registerName(ubyte index, char[] buffer) @nogc nothrow
{
	import core.stdc.stdio : snprintf;
	size_t length = 0;

	if (index == Register.IP)
		length = snprintf(buffer.ptr, buffer.length, "ip");
	else if (index == Register.SP)
		length = snprintf(buffer.ptr, buffer.length, "sp");
	else if (index == Register.BP)
		length = snprintf(buffer.ptr, buffer.length, "bp");
	else if (index == Register.Z)
		length = snprintf(buffer.ptr, buffer.length, "z");
	else if (index == Register.Flags)
		length = snprintf(buffer.ptr, buffer.length, "flags");
	else
		length = snprintf(buffer.ptr, buffer.length, "r%i", index);

	return buffer[0..length];
}