module common.cpu;

import common.util;

enum RegisterBitCount = 6;
enum RegisterCount = (1 << RegisterBitCount);

mixin EnumDocumented!("Register",
	"Z", RegisterCount - 5, 
		"Zero register (always 0). Any writes to this register will be discarded; " ~
		"any reads will always return 0.",
	"RA", RegisterCount - 4,
		"Return address (address to return to after the current function executes). " ~
		"To automatically save and restore the return address on the stack, " ~ 
		"use the `callsv` instruction.",
	"BP", RegisterCount - 3,
		"The stack base pointer (address of the start of this function's stack).",
	"SP", RegisterCount - 2,
		"The stack pointer (address of the element on the top of the stack). " ~
		"This is typically modified by pseudo-instructions like `push`, `pop`, and `callsv`.", 
	"IP", RegisterCount - 1,
		"The instruction pointer (address of the instruction being executed). " ~
		"This is modified by normal CPU operation, as well as jump/call instructions. " ~
		"This register can be the target of move instructions; the `jr` pseudoinstruction is " ~
		"a move instruction.",
	"Flags", RegisterCount - 0,
		"A bitmask of flags set by the CPU during operation. Typically used for " ~
		"conditional branching instructions."
);

// We may have "pseudo-registers" like Flags after the official register count.
// This includes them.
enum RegisterGeneralCount = Register.min;
enum RegisterExtendedCount = Register.max + 1;
alias RegisterType = uint;

enum Flags
{
	None,
	Zero = 1 << 0,
	Greater = 1 << 1,
	Less = 1 << 2
}

char[] registerName(Register index, char[] buffer) @nogc nothrow
{
	import std.traits : EnumMembers;
	import std.conv : to;
	import std.uni : toLower;
	import std.string : format;

	foreach (member; EnumMembers!Register)
	{
		enum loweredName = member.to!string.toLower.idup;

		if (index == member)
			return "%s".sformat(buffer, loweredName);
	}

	return "r%s".sformat(buffer, cast(ubyte)index);
}

string registerName(Register index)
{
	char[16] buffer;
	return index.registerName(buffer).idup;
}

Register registerFromName(string name)
{
	import std.traits : EnumMembers;
	import std.algorithm : all;
	import std.conv : to;
	import std.ascii : isDigit;
	import std.uni : toLower;	

	foreach (member; EnumMembers!Register)
	{
		if (name == member.to!string().toLower())
			return member;
	}

	if (name[0] == 'r' && name.length > 1 && name[1..$].all!isDigit)
	{
		auto index = name[1..$].to!ubyte();
	
		if (index >= RegisterGeneralCount)
			throw new Exception("Invalid register index");

		return cast(Register)index;
	}

	throw new Exception("Invalid register");
}