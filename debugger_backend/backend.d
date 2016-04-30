import common.debugging;
import common.socket;

public import common.util;
public import common.cpu;
public import common.opcode;

import std.utf;
import std.conv;
import std.process;
import std.parallelism;

import core.thread;

struct Core
{
	uint index;
	bool running;
	RegisterType[RegisterExtendedCount] registers;

	Debugger parent;

	this(uint index, Debugger parent)
	{
		this.index = index;
		this.parent = parent;
	}

	void getState()
	{
		this.parent.sendMessage!CoreGetState(this.index);
	}

	void setRunning(bool running)
	{
		this.parent.sendMessage!CoreSetRunning(this.index, running);
	}

	void step()
	{
		this.parent.sendMessage!CoreStep(this.index);
	}
}

class Debugger
{
	NonBlockingSocket connection;
	Core[] cores;
	Opcode[] opcodes;

	ProcessPipes spawnedProcess;

	uint textBegin;
	uint textEnd;

	void delegate() onInitialize;
	void delegate() onDisconnect;
	void delegate(string s) onLog;

	void delegate(Core*) onCoreState;
	void delegate(Core*) onCoreHalt;
	void delegate() onSystemOpcodes;
	void delegate(uint, ubyte[]) onSystemMemory;

	void spawnEmulator(string filePath, ushort port = 1234, bool redirectStdout = false, string[] args = ["--paused"])
	{
		import core.thread : Thread;
		import core.time : msecs;

		auto redirect = redirectStdout ? Redirect.stdout : cast(Redirect)0;
		auto portStr = port.to!string();
		args ~= ["--port", portStr];
		this.spawnedProcess = pipeProcess(["emulator", filePath] ~ args, redirect);
		task({
			Thread.getThis.sleep(50.msecs);

			if (this.spawnedProcess.pid.tryWait.terminated)
			{
				if (redirectStdout)
				{
					foreach (line; this.spawnedProcess.stdout.byLineCopy)
						this.onLog(line);
					this.onDisconnect();
				}

				return;
			}

			this.connect("127.0.0.1", portStr);
		}).executeInNewThread();
	}

	void waitForSpawnedEmulator()
	{
		this.spawnedProcess.pid.wait();
	}

	void connect(string ipAddress, string port)
	{
		import std.socket : getAddress;

		auto address = getAddress(ipAddress, port.to!ushort)[0];
		this.connection = NonBlockingSocket(
			AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);

		auto connectionAttempt = this.connection.connect(address);
	}

	void disconnect()
	{
		if (!this.connection.isValid)
			return;

		this.connection.shutdown(SocketShutdown.BOTH);
		this.connection.close();
		
		if (this.onDisconnect !is null)
			this.onDisconnect();

		this.cores = [];
	}

	void sendMessage(T)(ref T message)
		if (isSerializableMessage!T)
	{
		if (!this.connection.isValid)
			return;

		auto buffer = StackBuffer!(T.sizeof)(message.length);
		this.connection.send(message.serialize(buffer));
	}

	void sendMessage(T, Args...)(auto ref Args args)
	{
		auto message = T(args);
		this.sendMessage(message);
	}

	void getMemory(uint begin, uint end)
	{
		this.sendMessage!SystemGetMemory(begin, end);
	}

	void shutdown()
	{
		this.sendMessage!Shutdown();
		this.disconnect();
	}

	void handleSocket()
	{
		if (!this.connection.isValid)
			return;

		ushort length;
		auto size = this.connection.receive(length);
		length = length.ntohs();

		if (size == 0)
		{
			this.connection = NonBlockingSocket();
		}
		else if (size > 0)
		{
			auto buffer = StackBuffer!1024(length);
			auto readLeft = length;

			while (readLeft)
				readLeft -= this.connection.receive(buffer[(length - readLeft)..length]);

			this.handleMessage(buffer[0..length]);
		}
	}

	Core* createCore(uint index)
	{
		auto core = Core(index, this);
		this.cores ~= core;

		core.getState();
		return &this.cores[$-1];
	}

	void handleMessage(ubyte[] buffer)
	{
		auto messageId = cast(DebugMessageId)buffer[0];

		switch (messageId)
		{
		case DebugMessageId.Initialize:
			auto initialize = buffer.deserializeMessage!Initialize();
			this.textBegin = initialize.textBegin;
			this.textEnd = initialize.textEnd;

			foreach (coreIndex; 0 .. initialize.coreCount)
				this.createCore(coreIndex);

			if (this.onInitialize !is null)
				this.onInitialize();
			this.getMemory(this.textBegin, this.textEnd);
			break;
		case DebugMessageId.CoreState:
			auto coreState = buffer.deserializeMessage!CoreState();

			auto core = &this.cores[coreState.core];
			core.running = coreState.running;
			core.registers = coreState.registers;
			if (this.onCoreState !is null)
				this.onCoreState(core);
			break;
		case DebugMessageId.CoreHalt:
			auto coreHalt = buffer.deserializeMessage!CoreHalt();

			auto core = &this.cores[coreHalt.core];
			if (this.onCoreHalt !is null)
				this.onCoreHalt(core);
			break;
		case DebugMessageId.SystemMemory:
			auto systemMemory = buffer.deserializeMessage!SystemMemory();

			auto memory = systemMemory.memory.dup;
			auto memoryBegin = systemMemory.address;
			auto memoryEnd = memoryBegin + memory.length;

			if (memoryBegin == this.textBegin && memoryEnd == this.textEnd)
			{
				this.opcodes = cast(Opcode[])systemMemory.memory;
				if (this.onSystemOpcodes !is null)
					this.onSystemOpcodes();
			}
			if (this.onSystemMemory !is null)
				this.onSystemMemory(memoryBegin, memory);
			break;
		default:
			assert(0);
		}
	}
}
