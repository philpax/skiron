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
import common.program;

import emulator.state;

import emulator.device.device;
import emulator.device.screen;
import emulator.device.keyboard;

import arsd.simpledisplay;

string assembleIfNecessary(string filePath)
{
	import std.process : execute;

	if (filePath.extension() != ".skasm")
		return filePath;

	writefln("Assembling '%s'", filePath);
	auto assembler = ["assembler", filePath].execute();

	if (assembler.status != 0)
	{
		writefln("Failed to assemble '%s'", filePath);
		writefln("Assembler output: %s", assembler.output);
		return null;
	}
	else
	{
		writefln("Successfully assembled '%s'", filePath);
	}

	return filePath.setExtension(".bin");
}

void handleWindow(ref State state, Screen screen, Keyboard keyboard, Thread processThread)
{	
	auto window = new SimpleWindow(screen.width, screen.height, "Skiron Emulator");
	auto displayImage = new Image(window.width, window.height);

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

	state.forceShutdown = true;
}

void main(string[] args)
{
	// Read config
	Config config;
	args.getopt(
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

	// Validate user path
	auto filePath = args[1];
	if (!filePath.exists())
	{
		writefln("File '%s' does not exist", filePath);
		return;
	}

	// Assemble if required
	filePath = filePath.assembleIfNecessary();
	if (!filePath)
		return;
	
	// Read and parse program
	Program program;
	auto file = cast(ubyte[])filePath.read();

	if (!file.parseProgram(program))
		return writeln("Failed to parse Skiron program");

	// Create IO devices
	auto screen = new Screen(0x1_000_000, config.width, config.height);
	auto keyboard = new Keyboard(0x512_000);
	Device[] devices = [screen, keyboard];

	// Create state
	writeln("Skiron Emulator");
	auto state = State(config, devices);
	state.load(program);

	// Create threads to drive state and debugger
	auto stopWatch = StopWatch(AutoStart.yes);
	auto processThread = new Thread(() => state.run()).start();
	auto debuggerThread = new Thread({
		while (state.cores.any!(a => a.running) || state.client.isValid)
			state.handleDebuggerConnection();
	}).start();

	// Spawn a window
	state.handleWindow(screen, keyboard, processThread);

	// Wait for threads
	processThread.join();
	debuggerThread.join();
	stopWatch.stop();

	// Print performance stats
	auto secondsTaken = stopWatch.peek.msecs / 1000.0f;
	writefln("Total ticks: %s", state.totalTicks);
	writefln("Total time: %s s", secondsTaken);
	writefln("Average ticks/second: %s", state.totalTicks / secondsTaken);
	writefln("Average ms/tick: %s ms", (secondsTaken * 1000.0f) / state.totalTicks);
}