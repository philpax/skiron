module emulator.state;

public import common.cpu;
public import common.opcode;

import emulator.memory;
import emulator.arithmetic;
import emulator.controlflow;

import core.stdc.stdlib;
import core.stdc.stdio;

string generateOpcodeSwitch()
{
	import std.traits, std.string, std.conv;
	string s = "final switch (this.memory[this.ip])\n";
	s ~= "{\n";
	foreach (member; EnumMembers!Opcodes)
	{
		auto memberName = member.to!string();
		s ~= format(
`case Opcodes.%s.opcode:
	if (printOpcodes)
		printf("%%i: %%s\n", this.ip, "%s".ptr);
	this.run%s(Opcode(*cast(uint*)&this.memory[this.ip]));
	break;
`,		memberName, member.name, memberName);
	}
	s ~= "}\n";
	return s;
}

@nogc:
nothrow:

struct State
{
@nogc:
nothrow:
	uint[RegisterCount] registers;
	ubyte[] memory;
	bool running = true;
	bool printOpcodes = true;
	bool printRegisters = true;

	@disable this();

	this(uint memorySize)
	{
		this.memory = cast(ubyte[])malloc(memorySize)[0..memorySize];
	}

	~this()
	{
		free(this.memory.ptr);
	}

	@property ref uint ip()
	{
		return this.registers[Register.IP];
	}

	@property ref uint sp()
	{
		return this.registers[Register.SP];
	}

	@property ref uint bp()
	{
		return this.registers[Register.BP];
	}

	void run()
	{
		while (running)
		{
			mixin(generateOpcodeSwitch());
			if (this.printRegisters)
			{
				foreach (register; registers)
					printf("%i ", register);

				printf("\n");
			}
			this.ip += uint.sizeof;
		}
	}
}

ref uint getDst(ref State state, Opcode opcode)
{
	return state.registers[opcode.register1];
}

ref uint getSrc1(ref State state, Opcode opcode)
{
	return state.registers[opcode.register2];
}

alias getSrc = getSrc1;

ref uint getSrc2(ref State state, Opcode opcode)
{
	return state.registers[opcode.register2];
}