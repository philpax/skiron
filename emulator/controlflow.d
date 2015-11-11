module emulator.controlflow;

import emulator.state;

@nogc:
nothrow:

void runHalt(ref Core core, Opcode opcode)
{
	core.running = false;
}

void runCmp(Type = uint)(ref Core core, Opcode opcode)
{
	import std.traits;

	auto src1 = core.getDst!(Signed!Type)(opcode);
	auto src2 = core.getSrc!(Signed!Type)(opcode);
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
	core.ip += opcode.offset;
}

void runJe(ref Core core, Opcode opcode)
{
	if (core.flags & Flags.Zero)
		core.ip += opcode.offset;
}

void runJne(ref Core core, Opcode opcode)
{
	if (!(core.flags & Flags.Zero))
		core.ip += opcode.offset;
}

void runJgt(ref Core core, Opcode opcode)
{
	if (core.flags & Flags.Greater)
		core.ip += opcode.offset;
}

void runJlt(ref Core core, Opcode opcode)
{
	if (core.flags & Flags.Less)
		core.ip += opcode.offset;
}