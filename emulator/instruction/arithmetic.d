module emulator.instruction.arithmetic;

import emulator.core;

@nogc:
nothrow:

void runNot(Type = uint)(ref Core core, Opcode opcode)
{
	core.dst!Type(opcode) = ~core.src!Type(opcode);
}