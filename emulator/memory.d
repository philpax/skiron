module emulator.memory;

import emulator.state;

@nogc:
nothrow:

void runLoad(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, *cast(Type*)&core.memory[core.getSrc(opcode)]);
}

void runStore(Type = uint)(ref Core core, Opcode opcode)
{
	*cast(Type*)&core.memory[core.getDst(opcode)] = core.getSrc!Type(opcode);
}

void runLoadLi(ref Core core, Opcode opcode)
{
	ushort immediate = core.getImmediate(opcode) & 0xFFFF;
	core.setDst(opcode, (core.getDst(opcode) & 0xFFFF0000) | immediate);
}

void runLoadUi(ref Core core, Opcode opcode)
{
	ushort immediate = core.getImmediate(opcode) & 0xFFFF;
	core.setDst(opcode, (core.getDst(opcode) & 0x0000FFFF) | (immediate << 16));
}

void runMove(Type = uint)(ref Core core, Opcode opcode)
{
	core.setDst!Type(opcode, core.getSrc!Type(opcode));
}