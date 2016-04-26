module emulator.state;

public import common.cpu;
public import common.opcode;
import common.socket;
import common.debugging;
import common.util;

import emulator.memory;
import emulator.arithmetic;
import emulator.controlflow;
import emulator.screen;

import core.stdc.stdlib;
import core.stdc.stdio;

import std.algorithm;

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

		if (OperandFormatToOperandSizeSupport[member.operandFormat])
		{
			s ~= format(
`case Opcodes.%1$s.opcode:
	final switch (opcode.operandSize)
	{
		case OperandSize.Byte:
			this.run%1$s!ubyte(opcode);
			break;
		case OperandSize.Byte2:
			this.run%1$s!ushort(opcode);
			break;
		case OperandSize.Byte4:
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
	bool doStep = false;

	bool printOpcodes = true;
	bool printRegisters = true;
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
		if (this.paused && !this.doStep)
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

		if (this.doStep)
		{
			this.sendState();
			this.doStep = false;
		}
	}

	void sendState()
	{
		this.state.sendMessage!CoreState(this.id, !this.paused && this.running, this.registers);
	}
}

struct Config
{
	uint memorySize = 1024 * 1024;
	uint coreCount = 1;
	ushort port = 1234;
	bool printOpcodes = false;
	bool printRegisters = false;
	bool paused = false;
	uint width = 640;
	uint height = 480;
}

struct State
{
@nogc:
nothrow:
	ubyte[] memory;
	Core[] cores;

	Screen screen;

	uint textEnd = 0;
	NonBlockingSocket server;
	NonBlockingSocket client;

	@disable this();

	this(const ref Config config)
	{
		this.memory = cast(ubyte[])malloc(config.memorySize)[0..config.memorySize];
		this.cores = (cast(Core*)malloc(config.coreCount * Core.sizeof))[0..config.coreCount];
		printf("Memory: %u kB | Core count: %u\n", this.memory.length/1024, this.cores.length);

		this.screen = Screen(0x1_000_000, config.width, config.height);
		printf("Screen: Created, memory map size: %u bytes\n", this.screen.mapSize);

		this.server = NonBlockingSocket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
		this.server.bind(config.port);
		this.server.listen(1);
		printf("Debugger: Waiting for connection on port %i\n", config.port);

		uint index = 0;

		foreach (ref core; this.cores)
		{
			core = Core(this, index++, config.printOpcodes, config.printRegisters);
			core.paused = config.paused;
		}
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
		if (!this.client.isValid)
			return;

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
			this.cores[coreGetState.core].sendState();
			break;
		case DebugMessageId.CoreSetRunning:
			auto coreSetRunning = buffer.deserializeMessage!CoreSetRunning();

			auto core = &this.cores[coreSetRunning.core];
			core.paused = !coreSetRunning.running;
			core.sendState();
			break;
		case DebugMessageId.CoreStep:
			auto coreStep = buffer.deserializeMessage!CoreStep();

			this.cores[coreStep.core].doStep = true;
			break;
		case DebugMessageId.SystemGetMemory:
			auto systemGetMemory = buffer.deserializeMessage!SystemGetMemory();

			auto begin = systemGetMemory.begin;
			auto end = systemGetMemory.end;

			this.sendMessage!SystemMemory(begin, this.memory[begin..end]);
			break;
		case DebugMessageId.Shutdown:
			foreach (ref core; this.cores)
				core.running = false;

			this.client.shutdown(SocketShutdown.BOTH);
			this.client.close();
			break;
		default:
			assert(0);
		}
	}

	void run()
	{
		import std.algorithm : any;

		while (this.cores.any!(a => a.running) || this.client.isValid)
		{
			this.handleDebuggerConnection();

			foreach (ref core; this.cores.filter!(a => a.running))
			{
				core.step();

				if (!core.running)
				{
					core.sendState();
					this.sendMessage!CoreHalt(core.id);
				}
			}
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
	final switch (opcode.encoding)
	{
		case Encoding.A:
			assert(0);
		case Encoding.B:
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