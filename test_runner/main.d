import std.file;
import std.stdio;
import std.string;
import std.algorithm;
import std.range;
import std.typecons;
import std.conv;
import std.parallelism;
import std.path;

import common.cpu;

import debugger_backend.backend;

void main()
{
	RegisterType[Register][string] targets;

	foreach (filePath; "../tests".dirEntries("*.skasm", SpanMode.depth))
	{
		auto fileText = filePath.readText();

		if (fileText.empty)
			continue;

		auto headerLine = fileText.lineSplitter.front;
		auto registerTargets = headerLine.findSplit("TEST: ")[2]
										 .splitter(",")
			                             .map!(a => a.strip.split)
										 .map!(a => tuple(a[0].registerFromName(), a[1].to!RegisterType))
										 .assocArray();

		if (registerTargets.length == 0)
			continue;

		targets[filePath] = registerTargets;
	}

	foreach (filePath; targets.byKey)
	{
		auto registerTargets = targets[filePath];
		auto fileName = filePath.baseName();

		bool run = true;
		auto debugger = new Debugger();

		debugger.onInitialize = {
			debugger.cores[0].setRunning(true);
		};

		debugger.onCoreHalt = (Core* core) {
			if (core.running) return;

			bool success = true;

			foreach (register, value; registerTargets)
			{
				auto coreValue = core.registers[register];
				
				if (coreValue != value)
				{
					"[%s] %s: Expected %s, got %s".writefln(fileName, register.registerName(), value, coreValue);
					success = false;
				}
			}

			"[%s] %s".writefln(fileName, success ? "Test passed" : "Test failed");
			debugger.shutdown();
			debugger.waitForSpawnedEmulator();
			run = false;
		};

		debugger.spawnEmulator(filePath, true);

		while (run)
			debugger.handleSocket();
	}
}