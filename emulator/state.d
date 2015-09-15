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
		s ~= format(
`case Opcodes.%s.opcode:
	auto opcode = Opcode(*cast(uint*)&this.memory[this.ip]);
	if (printOpcodes)
	{
		char[64] buffer;
		auto inst = opcode.disassemble(buffer);
		printf("%%i: %%.*s\n", this.ip, inst.length, inst.ptr);
	}
	this.run%s(opcode);
	break;
`,		member.to!string(), member.to!string());
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

uint getDst(ref State state, Opcode opcode)
{
	return state.registers[opcode.register1];
}

void setDst(ref State state, Opcode opcode, uint value)
{
	if (opcode.register1 == Register.Z)
		return;
	else
		state.registers[opcode.register1] = value;
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