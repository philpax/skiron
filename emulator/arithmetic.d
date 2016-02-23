module emulator.arithmetic;

import emulator.state;

@nogc:
nothrow:

void runAddA(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc1!Type(opcode) + core.getSrc2!Type(opcode));
}

void runAddB(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getDst(opcode) + opcode.immediate);
}

void runAddD(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc1(opcode) + opcode.immediate9);
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

void runNot(ref Core core, Opcode opcode)
{
	core.setDst(opcode, ~core.getSrc(opcode));
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