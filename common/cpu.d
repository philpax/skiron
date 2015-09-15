module common.cpu;

enum RegisterCount = 64;
enum Register
{
	// Zero register (always 0)
	Z = 60,
	// Stack base pointer
	BP = 61,
	// Stack top pointer
	SP = 62,
	// Instruction pointer
	IP = 63
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
	else
		length = snprintf(buffer.ptr, buffer.length, "r%i", index);

	return buffer[0..length];
}