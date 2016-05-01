module common.program;

import common.opcode;

struct ProgramHeader
{
	uint magicCode = 0xDDBF;
	uint sectionCount;
}

struct ProgramSection
{
@nogc:
nothrow:
	enum NameLength = 8;

	char[NameLength] nameRaw;
	uint begin;
	uint end;

	const(char)[] name() @property const
	{
		import std.string : fromStringz;
		return this.nameRaw.ptr.fromStringz();
	}

	void name(string s) @property
	{
		this.nameRaw[] = s;
		this.nameRaw[s.length] = '\0';
	}

	uint size() @property const
	{
		return this.end - this.begin;
	}
}

struct Program
{
@nogc:
nothrow:
	const(ubyte)[] rawFile;
	ProgramHeader header;
	ProgramSection[] sections;
	Opcode[] opcodes;
	uint textBegin;
	uint textEnd;

	const(ubyte)[] getSection(string name) const
	{
		foreach (ref section; this.sections)
			if (section.name == name)
				return this.rawFile[section.begin .. section.end];

		return [];
	}
}

bool parseProgram(const(ubyte)[] file, out Program program) @nogc nothrow
{
	if (file.length < ProgramHeader.sizeof)
		return false;

	auto header = *cast(ProgramHeader*)file.ptr;
	if (header.magicCode != ProgramHeader.init.magicCode)
		return false;

	auto textBegin = cast(uint)(header.sizeof + ProgramSection.sizeof * header.sectionCount);
	auto textEnd = cast(uint)file.length;

	auto sections = cast(ProgramSection[])file[header.sizeof .. textBegin];
	foreach (section; sections)
	{
		if (section.name == ".text")
		{
			textBegin = section.begin;
			textEnd = section.end;
			break;
		}
	}

	auto opcodes = cast(Opcode[])file[textBegin .. textEnd];
	program = Program(file, header, sections, opcodes, textBegin, textEnd);
	return true;
}