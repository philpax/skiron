module emulator.instruction.arithmetic;

import emulator.core;

@nogc:
nothrow:

void runAddB(Type = uint)(ref Core core, Opcode opcode)
{
	core.dst!Type(opcode) = core.dst!Type(opcode) + core.getImmediate(opcode);
}

void runAddD(Type = uint)(ref Core core, Opcode opcode)
{
	core.dst!Type(opcode) = cast(Type)(core.src1!Type(opcode) + core.getImmediate(opcode));
}

void runNot(Type = uint)(ref Core core, Opcode opcode)
{
	core.dst!Type(opcode) = ~core.src!Type(opcode);
}