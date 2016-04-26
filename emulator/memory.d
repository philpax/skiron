module emulator.memory;

import emulator.state;

@nogc:
nothrow:

void runLoad(Type = uint)(ref Core core, Opcode opcode)
{
	auto address = core.getSrc!uint(opcode);
	auto value = 0;

	if (core.state.screen.isAddressMapped(address))
		value = core.state.screen.get!Type(address);
	else
		value = *cast(Type*)&core.memory[address];

	core.setDst!Type(opcode, value);
}

void runStore(Type = uint)(ref Core core, Opcode opcode)
{
	auto address = core.getDst!uint(opcode);
	auto value = core.getSrc!Type(opcode);

	if (core.state.screen.isAddressMapped(address))
		core.state.screen.set!Type(address, value);
	else
		*cast(Type*)&core.memory[core.getDst(opcode)] = value;
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