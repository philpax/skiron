module emulator.arithmetic;

import emulator.state;

@nogc:
nothrow:

void runAddA(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getSrc1(opcode) + state.getSrc2(opcode));
}

void runAddB(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getDst(opcode) + opcode.immediate);
}

void runSub(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getSrc1(opcode) - state.getSrc2(opcode));
}

void runMul(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getSrc1(opcode) * state.getSrc2(opcode));
}

void runDiv(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getSrc1(opcode) / state.getSrc2(opcode));
}

void runNot(ref State state, Opcode opcode)
{
	state.setDst(opcode, ~state.getSrc(opcode));
}

void runAnd(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getSrc1(opcode) & state.getSrc2(opcode));
}

void runOr(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getSrc1(opcode) | state.getSrc2(opcode));
}

void runXor(ref State state, Opcode opcode)
{
	state.setDst(opcode, state.getSrc1(opcode) ^ state.getSrc2(opcode));
}