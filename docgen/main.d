module docgen.main;

import std.file;
import std.path;

import docgen.opcodes;
import docgen.encodings;
import docgen.registers;

void main(string[] args)
{
	auto files = [writeOpcodes(), writeEncodings(), writeRegisters()];

	const wikiPath = "../skiron.wiki";
	if (wikiPath.exists && wikiPath.isDir)
	{
		foreach (file; files)
			std.file.copy(file, wikiPath.buildPath(file));
	}
}