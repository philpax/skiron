module common.cpu;

import common.util;

enum RegisterCount = (1 << 7);
enum Register
{
	// Zero register (always 0)
	Z = RegisterCount-5,
	// Return address (address to return to after current function executes)
	RA = RegisterCount-4,
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
	if (index == Register.IP)
		return "ip".sformat(buffer);
	else if (index == Register.SP)
		return "sp".sformat(buffer);
	else if (index == Register.BP)
		return "bp".sformat(buffer);
	else if (index == Register.Z)
		return "z".sformat(buffer);
	else if (index == Register.RA)
		return "ra".sformat(buffer);
	else if (index == Register.Flags)
		return "flags".sformat(buffer);
	else
		return "r%s".sformat(buffer, index);
}