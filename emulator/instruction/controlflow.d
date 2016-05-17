module emulator.instruction.controlflow;

import emulator.core;

@nogc:
nothrow:

void runHalt(ref Core core, Opcode opcode)
{
	core.running = false;
}

void runCmp(Type = uint)(ref Core core, Opcode opcode)
{
	import std.traits;

	auto src1 = core.dst!(Signed!Type)(opcode);
	auto src2 = core.src!(Signed!Type)(opcode);
	auto value = src1 - src2;

	if (value == 0)
		core.flags |= Flags.Zero;
	else
		core.flags &= ~Flags.Zero;

	if (value > 0)
		core.flags |= Flags.Greater;
	else
		core.flags &= ~Flags.Greater;

	if (value < 0)
		core.flags |= Flags.Less;
	else
		core.flags &= ~Flags.Less;
}

void runJ(ref Core core, Opcode opcode)
{
	core.ip += core.immediate(opcode);
}

void runJe(ref Core core, Opcode opcode)
{
	if (core.flags & Flags.Zero)
		core.ip += core.immediate(opcode);
}

void runJne(ref Core core, Opcode opcode)
{
	if (!(core.flags & Flags.Zero))
		core.ip += core.immediate(opcode);
}

void runJgt(ref Core core, Opcode opcode)
{
	if (core.flags & Flags.Greater)
		core.ip += core.immediate(opcode);
}

void runJlt(ref Core core, Opcode opcode)
{
	if (core.flags & Flags.Less)
		core.ip += core.immediate(opcode);
}