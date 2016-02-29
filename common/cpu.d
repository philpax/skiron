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
	string generateRegisterIf()
	{
		import std.traits : EnumMembers;
		import std.conv : to;
		import std.string : format;
		import std.uni : toLower;

		string ret = "";
		foreach (member; EnumMembers!Register)
		{
			string name = member.to!string();
			ret ~= "if (index == Register.%s) return \"%s\".sformat(buffer);\n".format(name, name.toLower());
		}

		ret ~= `else return "r%s".sformat(buffer, index);`;

		return ret;
	}

	
	mixin(generateRegisterIf());		
}