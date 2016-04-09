module emulator.state;

public import common.cpu;
public import common.opcode;
import common.socket;
import common.debugging;
import common.util;

import emulator.memory;
import emulator.arithmetic;
import emulator.controlflow;

import core.stdc.stdlib;
import core.stdc.stdio;

string generateOpcodeSwitch()
{
	import std.traits, std.string, std.conv;
	string s = 
`final switch (opcode.opcode)
{
`;
	foreach (member; EnumMembers!Opcodes)
	{
		if (member.operandFormat == OperandFormat.Pseudo)
			continue;

		if (member.supportsOperandSize)
		{
			s ~= format(
`case Opcodes.%1$s.opcode:
	final switch (opcode.operandSize)
	{
		case OperandSize.Byte:
			this.run%1$s!ubyte(opcode);
			break;
		case OperandSize.Dbyte:
			this.run%1$s!ushort(opcode);
			break;
		case OperandSize.Qbyte:
			this.run%1$s!uint(opcode);
			break;
	}
	break;
`, 
			member.to!string());
		}
		else
		{
			s ~= format(
`case Opcodes.%1$s.opcode:
	this.run%1$s(opcode);
	break;
`, 
			member.to!string());
		}
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
	RegisterType[RegisterExtendedCount] registers;
	bool running = true;
	// Changed by debugger
	bool paused = false;
	bool printOpcodes = true;
	bool printRegisters = true;
	bool printCurrent;
	uint id;

	@disable this();
	this(ref State state, uint id, bool printOpcodes, bool printRegisters)
	{
		this.state = &state;
		this.memory = state.memory;
		this.printOpcodes = printOpcodes;
		this.printRegisters = printRegisters;
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

	@property ref uint ra()
	{
		return this.registers[Register.RA];
	}

	@property ref uint flags()
	{
		return this.registers[Register.Flags];
	}

	void step()
	{
		if (this.paused)
			return;

		auto oldRegisters = this.registers;
		auto opcode = Opcode(*cast(uint*)&this.memory[this.ip]);

		if (this.printOpcodes)
		{
			char[64] buffer;
			auto inst = opcode.disassemble(buffer);
			printf("C%i %i: %.*s\n", this.id, this.ip, inst.length, inst.ptr);
		}

		this.ip += uint.sizeof;

		mixin(generateOpcodeSwitch());
		if (this.printRegisters)
		{
			char[8] name;
			bool first = true;
			foreach (index; 0 .. oldRegisters.length)
			{
				auto oldValue = oldRegisters[index];
				auto newValue = this.registers[index];

				if (oldValue == newValue)
					continue;

				auto reg = registerName(cast(Register)index, name);

				if (!first)
					printf(", ");

				printf("%.*s %X -> %X", reg.length, reg.ptr, oldValue, newValue);
				first = false;
			}

			printf("\n");
		}
	}
}

struct State
{
@nogc:
nothrow:
	ubyte[] memory;
	Core[] cores;
	uint textEnd = 0;
	NonBlockingSocket server;
	NonBlockingSocket client;

	@disable this();

	this(uint memorySize, uint coreCount, bool printOpcodes, bool printRegisters)
	{
		this.memory = cast(ubyte[])malloc(memorySize)[0..memorySize];
		this.cores = (cast(Core*)malloc(coreCount * Core.sizeof))[0..coreCount];
		printf("Memory: %u kB | Core count: %u\n", memorySize/1024, coreCount);

		this.server = NonBlockingSocket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
		this.server.bind(1234);
		this.server.listen(1);

		uint index = 0;

		foreach (ref core; this.cores)
			core = Core(this, index++, printOpcodes, printRegisters);
	}

	~this()
	{
		foreach (ref core; this.cores)
			core.__dtor();

		free(this.cores.ptr);
		free(this.memory.ptr);
	}

	void sendMessage(T)(ref T message)
		if (isSerializableMessage!T)
	{
		auto buffer = StackBuffer!(T.sizeof)(message.length);
		this.client.send(message.serialize(buffer));
	}

	void sendMessage(T, Args...)(auto ref Args args)
	{
		auto message = T(args);
		this.sendMessage(message);
	}

	void load(ubyte[] program)
	{
		this.memory[0 .. program.length] = program;
		this.textEnd = program.length;
	}

	void handleDebuggerConnection()
	{
		if (!this.client.isValid)
		{
			this.client = this.server.accept();

			if (this.client.isValid)
			{
				printf("Debugger: Connected (socket id: %d)\n", this.client.handle);

				Initialize initialize;
				initialize.coreCount = this.cores.length;
				initialize.memorySize = this.memory.length;
				initialize.textBegin = 0;
				initialize.textEnd = this.textEnd;
				this.sendMessage(initialize);
			}
		}

		if (this.client.isValid)
		{
			ushort length;
			auto size = this.client.receive(length);
			length = length.ntohs();

			if (size == 0)
			{
				printf("Debugger: Disconnected\n");
				this.client = NonBlockingSocket();
			}
			else if (size > 0)
			{
				auto buffer = StackBuffer!1024(length);
				auto readLeft = length;

				while (readLeft)
					readLeft -= this.client.receive(buffer[(length - readLeft)..length]);

				this.handleMessage(buffer[0..length]);
			}
		}
	}

	void handleMessage(ubyte[] buffer)
	{
		auto messageId = cast(DebugMessageId)buffer[0];

		switch (messageId)
		{
		case DebugMessageId.CoreGetState:
			auto coreGetState = buffer.deserializeMessage!CoreGetState();

			auto core = &this.cores[coreGetState.core];
			this.sendMessage!CoreState(core.id, !core.paused, core.registers);
			break;
		case DebugMessageId.SystemGetMemory:
			auto systemGetMemory = buffer.deserializeMessage!SystemGetMemory();

			auto begin = systemGetMemory.begin;
			auto end = systemGetMemory.end;

			this.sendMessage!SystemMemory(begin, this.memory[begin..end]);
			break;
		default:
			assert(0);
		}
	}

	void run()
	{
		import std.algorithm : any;

		while (this.cores.any!(a => a.running))
		{
			this.handleDebuggerConnection();

			foreach (ref core; this.cores)
				core.step();
		}
	}
}

Type getDst(Type = uint)(ref Core core, Opcode opcode)
{
	return cast(Type)core.registers[opcode.register1];
}

void setDst(Type = uint, IncomingType)(ref Core core, Opcode opcode, IncomingType value)
{
	if (opcode.register1 == Register.Z)
		return;
	else
		*cast(Type*)&core.registers[opcode.register1] = cast(Type)value;
}

Type doVariant(Type = uint)(Opcode opcode, Type value)
{
	final switch (opcode.variant)
	{
		case Variant.Identity:
			return value;
		case Variant.ShiftLeft1:
			return cast(Type)(value << 1);
		case Variant.ShiftLeft2:
			return cast(Type)(value << 2);
	}
}

int getImmediate(ref Core core, Opcode opcode)
{
	string generateB16Switch()
	{
			import std.traits, std.string, std.conv;

	string ret =
`bool isB16Necessary(Opcode opcode) @nogc nothrow
{
	switch (opcode.opcode)
	{
`;

		foreach (member; EnumMembers!Opcodes)
		{
			if (member.encoding != Encoding.B)
				continue;

			if (member.supportsOperandSize)
				continue;

			ret ~= "case Opcodes.%s.opcode: return true;\n".format(member.to!string());
		}

		ret ~= "default: return false;\n";
		ret ~= 
`	}
}`;

		return ret;
	}

	mixin(generateB16Switch());
	final switch (opcode.encoding)
	{
		case Encoding.A:
			assert(0);
		case Encoding.B:
			bool requiresB16 = isB16Necessary(opcode);

			if (requiresB16)
				return opcode.doVariant(opcode.immediateB16);
			else
				return opcode.doVariant(opcode.immediateB);
		case Encoding.C:
			return opcode.doVariant(opcode.immediateC);
		case Encoding.D:
			return opcode.doVariant(opcode.immediateD);
	}
}

Type getSrc(Type = uint)(ref Core core, Opcode opcode)
{
	return opcode.doVariant(cast(Type)core.registers[opcode.register2]);
}

Type getSrc1(Type = uint)(ref Core core, Opcode opcode)
{
	return cast(Type)core.registers[opcode.register2];
}

Type getSrc2(Type = uint)(ref Core core, Opcode opcode)
{
	return opcode.doVariant(cast(Type)core.registers[opcode.register3]);
}