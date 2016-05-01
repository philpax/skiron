module emulator.state;

import common.cpu;
import common.opcode;
import common.socket;
import common.debugging;
import common.util;
import common.program;

import emulator.core;

import emulator.device.device;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.atomic;

import std.algorithm;

struct Config
{
	uint memorySize = 1024 * 1024;
	uint coreCount = 1;
	ushort port = 1234;
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
	Device[] devices;

	uint textBegin = 0;
	uint textEnd = 0;

	NonBlockingSocket server;
	NonBlockingSocket client;

	uint ticksPerSecond;
	ulong totalTicks;

	shared bool forceShutdown = false;

	@disable this();

	this(const ref Config config, Device[] devices)
	{
		this.memory = cast(ubyte[])malloc(config.memorySize)[0..config.memorySize];
		this.cores = (cast(Core*)malloc(config.coreCount * Core.sizeof))[0..config.coreCount];
		printf("Memory: %u kB | Core count: %u\n", this.memory.length/1024, this.cores.length);

		this.devices = devices;

		this.server = NonBlockingSocket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
		this.server.bind(config.port);
		this.server.listen(1);
		printf("Debugger: Waiting for connection on port %i\n", config.port);

		uint index = 0;
		foreach (ref core; this.cores)
			core = Core(this, index++, config.paused);
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

	void load(const ref Program program)
	{
		auto opcodes = cast(ubyte[])program.opcodes;
		
		this.textBegin = 0;
		this.textEnd = opcodes.length;
		this.memory[textBegin .. textEnd] = opcodes;
		
		auto dataSection = program.getSection(".data");
		if (dataSection.length)
			this.memory[textEnd .. textEnd + dataSection.length] = dataSection;
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
				initialize.textBegin = this.textBegin;
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

	void shutdown()
	{	
		foreach (ref core; this.cores)
			core.running = false;

		this.client.shutdown(SocketShutdown.BOTH);
		this.client.close();
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
			this.shutdown();
			break;
		default:
			assert(0);
		}
	}

	void run()
	{
		import std.algorithm : any;
		import core.time : MonoTime, seconds;

		auto tickBeginTime = MonoTime.currTime;
		auto tickCounter = 0;

		while (this.cores.any!(a => a.running) || this.client.isValid)
		{
			foreach (ref core; this.cores.filter!(a => a.running))
			{
				core.step();

				if (!core.running)
				{
					core.sendState();
					this.sendMessage!CoreHalt(core.id);
				}
			}

			tickCounter++;
			this.totalTicks++;

			if ((MonoTime.currTime - tickBeginTime) > 1.seconds)
			{
				this.ticksPerSecond = tickCounter;
				tickCounter = 0;
				tickBeginTime = MonoTime.currTime;
			}

			if (this.forceShutdown.atomicLoad())
				this.shutdown();
		}
	}
}