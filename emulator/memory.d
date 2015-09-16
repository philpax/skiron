module emulator.memory;

import emulator.state;

@nogc:
nothrow:

void runLoad(ref Core core, Opcode opcode)
{
	core.setDst(opcode, *cast(uint*)&core.memory[core.getSrc(opcode)]);
}

void runStore(ref Core core, Opcode opcode)
{
	*cast(uint*)&core.memory[core.getDst(opcode)] = core.getSrc(opcode);
}

void runLoadLi(ref Core core, Opcode opcode)
{
	ushort immediate = opcode.immediate & 0xFFFF;
	core.setDst(opcode, (core.getDst(opcode) & 0xFFFF0000) | immediate);
}

void runLoadUi(ref Core core, Opcode opcode)
{
	ushort immediate = opcode.immediate & 0xFFFF;
	core.setDst(opcode, (core.getDst(opcode) & 0x0000FFFF) | (immediate << 16));
}

void runMove(ref Core core, Opcode opcode)
{
	core.setDst(opcode, core.getSrc(opcode));
}