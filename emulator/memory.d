module emulator.memory;

import emulator.state;

@nogc:
nothrow:

void runLoad(ref State state, Opcode opcode)
{
	state.getDst(opcode) = *cast(uint*)&state.memory[state.getSrc(opcode)];
}

void runStore(ref State state, Opcode opcode)
{
	*cast(uint*)&state.memory[state.getDst(opcode)] = state.getSrc(opcode);
}

void runLoadLi(ref State state, Opcode opcode)
{
	ushort immediate = opcode.immediate & 0xFFFF;
	state.getDst(opcode) = (state.getDst(opcode) & 0xFFFF0000) | immediate;
}

void runLoadUi(ref State state, Opcode opcode)
{
	ushort immediate = opcode.immediate & 0xFFFF;
	state.getDst(opcode) = (state.getDst(opcode) & 0x0000FFFF) | (immediate << 16);
}

void runMove(ref State state, Opcode opcode)
{
	state.getDst(opcode) = state.getSrc(opcode);
}