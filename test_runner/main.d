import std.file;
import std.stdio;
import std.string;
import std.algorithm;
import std.range;
import std.typecons;
import std.conv;
import std.parallelism;
import std.path;
import std.traits;

import common.cpu;

import debugger_backend.backend;

void main()
{
	alias TargetType = Signed!RegisterType;

	struct Test
	{
		string name;
		string path;
		TargetType[Register] targets;
	}

	Test[] tests;

	foreach (filePath; "../tests".dirEntries("*.skasm", SpanMode.depth))
	{
		auto fileText = filePath.readText();

		if (fileText.empty)
			continue;

		auto headerLine = fileText.lineSplitter.front;
		auto registerTargets = headerLine.findSplit("TEST: ")[2]
										 .splitter(",")
										 .map!(a => a.strip.split)
										 .map!(a => tuple(a[0].registerFromName(), cast(TargetType)a[1].to!long))
										 .assocArray();

		if (registerTargets.length == 0)
			continue;

		tests ~= Test(filePath.baseName.stripExtension(), filePath, registerTargets);
	}

	writeln("== Tests: ", tests.map!(a => a.name).join(", "), " ==");

	foreach (test; tests)
	{
		bool run = true;
		auto debugger = new Debugger();

		debugger.onInitialize = {
			debugger.cores[0].setRunning(true);
		};

		debugger.onDisconnect = {
			run = false;
		};

		debugger.onLog = (string s) {
			"%s | %s".writefln(test.name, s);
		};

		debugger.onCoreHalt = (Core* core) {
			if (core.running) return;

			bool success = true;

			foreach (register, value; test.targets)
			{
				auto coreValue = cast(TargetType)core.registers[register];
				
				if (coreValue != value)
				{
					"%s | %s: Expected %s, got %s".writefln(test.name, register.registerName(), value, coreValue);
					success = false;
				}
			}

			"%s | %s".writefln(success ? "Pass" : "Fail", test.name);
			debugger.shutdown();
			debugger.waitForSpawnedEmulator();
			run = false;
		};

		debugger.spawnEmulator(test.path, 1234, true);

		while (run)
			debugger.handleSocket();
	}
}