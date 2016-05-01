module emulator.device.keyboard;

import emulator.device.device;

class Keyboard : Device
{
	@MemoryMap(0, AccessMode.Read)
	uint key;
	
	this(uint address)
	{
		super(address);
	}

	mixin DeviceImpl;
}