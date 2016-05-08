module emulator.instruction.arithmetic;

import emulator.core;

@nogc:
nothrow:

void runAddB(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getDst!Type(opcode) + core.getImmediate(opcode));
}

void runAddD(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) + core.getImmediate(opcode));
}

void runNot(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, ~core.getSrc!Type(opcode));
}