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

void runSub(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) - core.getSrc2!Type(opcode));
}

void runMul(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) * core.getSrc2!Type(opcode));
}

void runDiv(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) / core.getSrc2!Type(opcode));
}

void runNot(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, ~core.getSrc!Type(opcode));
}

void runAnd(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) & core.getSrc2!Type(opcode));
}

void runOr(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) | core.getSrc2!Type(opcode));
}

void runXor(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) ^ core.getSrc2!Type(opcode));
}

void runShl(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) << core.getSrc2!Type(opcode));
}

void runShr(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) >> core.getSrc2!Type(opcode));
}