module emulator.instruction.memory;

import emulator.core;
import emulator.state;

@nogc:
nothrow:

void runLoad(Type = uint)(ref Core core, Opcode opcode)
{
	auto address = core.src!uint(opcode);
	void* dataPtr = &core.memory.ptr[address];

	foreach (device; core.state.devices)
	{
		if (device.isAddressMapped(address))
		{
			dataPtr = device.map(address);
			break;
		}
	}

	core.dst!Type(opcode) = *cast(Type*)dataPtr;
}

void runStore(Type = uint)(ref Core core, Opcode opcode)
{
	auto address = core.dst!uint(opcode);
	auto value = core.src!Type(opcode);
	void* dataPtr = &core.memory.ptr[address];

	foreach (device; core.state.devices)
	{
		if (device.isAddressMapped(address))
		{
			dataPtr = device.map(address);
			break;
		}
	}
	
	*cast(Type*)dataPtr = value;
}

void runLoadLi(ref Core core, Opcode opcode)
{
	ushort immediate = core.immediate(opcode) & 0xFFFF;
	core.dst(opcode) = (core.dst(opcode) & 0xFFFF0000) | immediate;
}

void runLoadUi(ref Core core, Opcode opcode)
{
	ushort immediate = core.immediate(opcode) & 0xFFFF;
	core.dst(opcode) = (core.dst(opcode) & 0x0000FFFF) | (immediate << 16);
}

void runMove(Type = uint)(ref Core core, Opcode opcode)
{
	core.dst!Type(opcode) = core.src!Type(opcode);
}