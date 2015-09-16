module emulator.arithmetic;

import emulator.state;

@nogc:
nothrow:

void runAddA(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) + core.getSrc2(opcode));
}

void runAddB(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getDst(opcode) + opcode.immediate);
}

void runSub(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) - core.getSrc2(opcode));
}

void runMul(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) * core.getSrc2(opcode));
}

void runDiv(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) / core.getSrc2(opcode));
}

void runNot(ref Core core, Opcode opcode)
{
	core.setDst(opcode, ~core.getSrc(opcode));
}

void runAnd(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) & core.getSrc2(opcode));
}

void runOr(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) | core.getSrc2(opcode));
}

void runXor(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) ^ core.getSrc2(opcode));
}