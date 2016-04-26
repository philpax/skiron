import core.memory;
import core.thread;

import std.file;
import std.path;
import std.stdio;
import std.getopt;

import common.util;

import emulator.state;

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

	GC.collect();
	GC.disable();

	auto window = new SimpleWindow(config.width, config.height);
	auto displayImage = new Image(window.width, window.height);
	
	printf("Skiron Emulator\n");
	auto state = State(config);
	state.load(program);

	auto processThread = new Thread(() => state.run()).start();

	window.eventLoop(16, ()
	{
		// Do more efficiently at a later stage
		foreach (y; 0..displayImage.height)
		{
			foreach (x; 0..displayImage.width)
			{
				auto screen = &state.screen;
				auto pixel = screen.pixels[y * screen.width + x];
				displayImage[x, y] = Color(pixel.r, pixel.g, pixel.b);
			}
		}

		auto screenPainter = window.draw();
		screenPainter.drawImage(Point(0, 0), displayImage);
	});
	processThread.join();
}