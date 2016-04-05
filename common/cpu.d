module common.cpu;

import common.util;

import std.typecons : tuple;
import std.meta : AliasSeq;

enum RegisterBitCount = 6;
enum RegisterCount = (1 << RegisterBitCount);

private template SelectTwo(uint Index1, uint Index2, Args...)
{
	static if (Args.length == 3)
	{
		enum SelectTwo = tuple(Args[Index1], Args[Index2]);
	}
	else
	{
		enum SelectTwo = AliasSeq!(
			SelectTwo!(Index1, Index2, Args[0..3]), 
			SelectTwo!(Index1, Index2, Args[3..$]));
	}
}

private string registers(Args...)()
{
	import std.string : format;

	string ret = "enum Register { ";
	foreach (value; SelectTwo!(0, 1, Args))
		ret ~= `%s = %s, `.format(value.expand);
	ret ~= "}\n";
	ret ~= "enum RegisterDocs = [";
	foreach (value; SelectTwo!(0, 2, Args))
		ret ~= `tuple(Register.%s, "%s"), `.format(value.expand);
	ret ~= "];\n";

	return ret;
}

mixin(registers!(
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
		"The stack pointer (address of the element on the top of the stack).", 
	"IP", RegisterCount - 1,
		"The instruction pointer (address of the instruction being executed).",
	"Flags", RegisterCount - 0,
		"A bitmask of flags set by the CPU during operation. Typically used for " ~
		"conditional branching instructions."
));

// We may have "pseudo-registers" like Flags after the official register count.
// This includes them.
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

		ret ~= `else return "r%s".sformat(buffer, cast(ubyte)index);`;

		return ret;
	}

	
	mixin(generateRegisterIf());		
}