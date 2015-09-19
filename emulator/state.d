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
	if (this.printOpcodes)
	{
		char[64] buffer;
		auto inst = opcode.disassemble(buffer);
		printf("C%%i %%i: %%.*s\n", this.id, this.ip, inst.length, inst.ptr);
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

struct Core
{
@nogc:
nothrow:
	State* state;
	ubyte[] memory;
	uint[RegisterCount] registers;
	bool running = true;
	bool printOpcodes = true;
	bool printRegisters = true;
	uint id;

	@disable this();
	this(ref State state, uint id)
	{
		this.state = &state;
		this.memory = state.memory;
		this.id = id;
	}

	~this() {}

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

	void step()
	{
		mixin(generateOpcodeSwitch());
		if (this.printRegisters)
		{
			printf("C%i ", this.id);
			foreach (register; registers)
				printf("%i ", register);

			printf("\n");
		}
		this.ip += uint.sizeof;
	}
}

struct State
{
@nogc:
nothrow:
	ubyte[] memory;
	Core[] cores;

	@disable this();

	this(uint memorySize, uint coreCount)
	{
		this.memory = cast(ubyte[])malloc(memorySize)[0..memorySize];
		this.cores = (cast(Core*)malloc(coreCount * Core.sizeof))[0..coreCount];

		uint index = 0;
		foreach (ref core; this.cores)
		{
			core = Core(this, index++);
		}
	}

	~this()
	{
		foreach (ref core; this.cores)
			core.__dtor();

		free(this.cores.ptr);
		free(this.memory.ptr);
	}

	void run()
	{
		import std.algorithm;

		while (this.cores.any!(a => a.running))
		{
			foreach (ref core; this.cores)
				core.step();
		}
	}
}

uint getDst(ref Core core, Opcode opcode)
{
	return core.registers[opcode.register1];
}

void setDst(ref Core core, Opcode opcode, uint value)
{
	if (opcode.register1 == Register.Z)
		return;
	else
		core.registers[opcode.register1] = value;
}

ref uint getSrc1(ref Core core, Opcode opcode)
{
	return core.registers[opcode.register2];
}

alias getSrc = getSrc1;

ref uint getSrc2(ref Core core, Opcode opcode)
{
	return core.registers[opcode.register3];
}