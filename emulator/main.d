import core.memory;
import core.thread;

import std.file;
import std.path;
import std.stdio;
import std.getopt;
import std.string;
import std.datetime;
import std.algorithm;

import common.util;

import emulator.state;
import emulator.screen;
import emulator.keyboard;

import arsd.simpledisplay;

void main(string[] args)
{
	Config config;
	args.getopt(
		"print-opcodes", &config.printOpcodes, 
		"print-registers", &config.printRegisters,
		"paused", &config.paused,
		"memory-size", &config.memorySize,
		"core-count", &config.coreCount,
		"port", &config.port,
		"width", &config.width,
		"height", &config.height);

	if (args.length < 2)
	{
		writeln("emulator filename");
		return;
	}

	auto filePath = args[1];
	if (!filePath.exists())
	{
		writefln("File '%s' does not exist", filePath);
		return;
	}

	if (filePath.extension() == ".skasm")
	{
		import std.process : execute;
		writefln("Assembling '%s'", filePath);
		auto assembler = ["assembler", filePath].execute();

		if (assembler.status != 0)
		{
			writefln("Failed to assemble '%s'", filePath);
			writefln("Assembler output: %s", assembler.output);
			return;
		}
		else
		{
			writefln("Successfully assembled '%s'", filePath);
		}

		filePath = filePath.setExtension(".bin");
	}

	auto program = cast(ubyte[])filePath.read();
	if (program.length < 4)
	{
		writefln("File '%s' too small", filePath);
		return;
	}

	if ((cast(uint*)program.ptr)[0] != HeaderMagicCode)
	{
		writefln("Expected file '%s' to start with Skiron header", filePath);
		return;
	}

	program = program[uint.sizeof .. $];

	auto window = new SimpleWindow(config.width, config.height, "Skiron Emulator");
	auto displayImage = new Image(window.width, window.height);

	auto screen = new Screen(0x1_000_000, config.width, config.height);
	auto keyboard = new Keyboard(0x512_000);
	Device[] devices = [screen, keyboard];

	writeln("Skiron Emulator");
	auto state = State(config, devices);
	state.load(program);

	auto stopWatch = StopWatch(AutoStart.yes);
	auto processThread = new Thread(() => state.run()).start();
	auto debuggerThread = new Thread({
		while (state.cores.any!(a => a.running) || state.client.isValid)
			state.handleDebuggerConnection();
	}).start();

	window.eventLoop(16, ()
	{
		if (!processThread.isRunning)
		{
			window.close();
			return;
		}

		// Do more efficiently at a later stage
		foreach (y; 0..displayImage.height)
		{
			foreach (x; 0..displayImage.width)
			{
				auto pixel = screen.pixels[y * screen.width + x];
				displayImage[x, y] = Color(pixel.r, pixel.g, pixel.b);
			}
		}

		auto screenPainter = window.draw();
		screenPainter.drawImage(Point(0, 0), displayImage);

		auto msPerTick = 1000.0f / state.ticksPerSecond;
		window.title = "Skiron Emulator (%s ticks/s, %s ms/tick)".format(state.ticksPerSecond, msPerTick);
	},
	(KeyEvent ke)
	{
		keyboard.key = ke.key;
	});

	processThread.join();
	stopWatch.stop();

	auto secondsTaken = stopWatch.peek.msecs / 1000.0f;
	writefln("Total ticks: %s", state.totalTicks);
	writefln("Total time: %s s", secondsTaken);
	writefln("Average ticks/second: %s", state.totalTicks / secondsTaken);
	writefln("Average ms/tick: %s ms", (secondsTaken * 1000.0f) / state.totalTicks);
}