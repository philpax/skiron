module emulator.controlflow;

import emulator.state;

@nogc:
nothrow:

void runHalt(ref State state, Opcode opcode)
{
	state.running = false;
}