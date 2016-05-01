module assembler.main;

import std.file;
import std.path;
import std.traits;
import std.string, std.ascii;
import std.conv;
import std.range;
import std.algorithm;
import std.stdio;

import core.stdc.stdlib;

import common.opcode;
import common.cpu;
import common.util;
import common.program;

import assembler.lexer;
import assembler.parse;
import assembler.general;
import assembler.pseudo;

void error(Args...)(string text, auto ref Args args)
{
	writefln(text, args);
	exit(EXIT_FAILURE);
}

void errorIf(Args...)(bool condition, auto ref Args args)
{
	if (condition)
		error(args);
}

void error(Args...)(ref const(Token) token, string text, auto ref Args args)
{
	error("[%s,%s]: " ~ text, token.line, token.column, args);
}

struct Assembler
{
	struct Relocation
	{
		enum Type
		{
			// Offset from this instruction to the target
			Offset,
			// Upper and lower 16-bits of the label, to be stored in the next two instructions
			SplitAbsolute
		}

		string label;
		size_t location;
		Type type;
	}

	ProgramSection[] sections;
	const(Token)[] tokens;
	uint[] output;

	Relocation[] relocations;
	uint[string] labels;

	size_t repCount = 1;

	OpcodeDescriptor[][string] descriptors;

	alias AssembleFunction = bool function(ref Assembler, const(OpcodeDescriptor)*);
	immutable AssembleFunction[string] pseudoAssemble;

	this(const(Token)[] tokens)
	{
		this.tokens = tokens;

		foreach (member; EnumMembers!Opcodes)
			this.descriptors[member.name] ~= member;

		// Construct the AA of pseudoinstructions => assemble functions
		auto generatePseudoAssemble()
		{
			enum opcodes = [EnumMembers!Opcodes];

			return "[%s]".format(
						opcodes.filter!(a => a.operandFormat == OperandFormat.Pseudo)
							   .map!(a => `"%s": &assemble%s`.format(a.name, a.to!string()))
							   .join(", "));
		}

		this.pseudoAssemble = mixin(generatePseudoAssemble());
	}

	void writeOutput(T)(ref const T value, uint offset = 0)
	{
		foreach (index, word; (cast(uint*)&value)[0..value.sizeof/uint.sizeof].enumerate)
		{
			if (offset)
				this.output[offset/uint.sizeof + index] = word;
			else
				this.output ~= word;
		}
	}

	uint getEndOffset() const
	{
		return cast(uint)(this.output.length * uint.sizeof);
	}

	uint writeHeader()
	{
		ProgramHeader header;
	
		// Prefill the labels AA, and build up the sections
		foreach (token; this.tokens)
		{
			if (token.type == tok!"label")
			{
				auto text = token.text;
				if (text in this.labels)
					token.error("Redefining label `%s`", text);
				this.labels[token.text] = 0;
			}
			else if (token.type == tok!"section")
			{
				header.sectionCount++;
			}
		}

		this.writeOutput(header);

		auto programSectionPoint = this.getEndOffset();

		foreach (_; 0..header.sectionCount)
		{
			auto section = ProgramSection();
			this.writeOutput(section);
		}

		return programSectionPoint;
	}

	void dispatchTokens()
	{
		while (!this.tokens.empty)
		{
			auto token = this.tokens.front;

			if (token.type == tok!"identifier")
				this.assembleIdentifierToken(token);
			else if (token.type == tok!"label")
				this.assembleLabelToken(token);
			else if (token.type == tok!"section")
				this.assembleSectionToken(token);
			else if (token.type == tok!"")
				break;
			else
				token.error("Unhandled token: %s.", token.to!string());
		}
	}

	void rewriteSections(uint programSectionPoint)
	{
		if (this.sections.length)
			this.sections[$-1].end = this.getEndOffset();

		foreach (index, section; this.sections.enumerate)
		{
			auto offset = programSectionPoint + (index * ProgramSection.sizeof);
			this.writeOutput(section, offset);
		}
	}

	void completeRelocations()
	{
		auto opcodes = cast(Opcode[])this.output;
		foreach (const relocation; this.relocations)
		{
			final switch (relocation.type)
			{
			case Relocation.Type.Offset:
				auto location = relocation.location;
				auto currentPosition = location * uint.sizeof;

				opcodes[location].immediateC =
					cast(int)(this.labels[relocation.label] - currentPosition - 4);
				break;
			case Relocation.Type.SplitAbsolute:
				auto location = relocation.location;
				auto label = this.labels[relocation.label];

				opcodes[location].immediateB = (label >> 16) & 0xFFFF;
				opcodes[location+1].immediateB = label & 0xFFFF;
				break;
			}
		}
	}

	void assemble()
	{
		auto programSectionPoint = this.writeHeader();
		this.dispatchTokens();
		this.rewriteSections(programSectionPoint);
		this.completeRelocations();
	}
}

void main(string[] args)
{
	import std.getopt, std.process;
	bool disassemble = false;
	args.getopt("disassemble|d", &disassemble);

	errorIf(args.length < 2, "expected at least one argument");
	string inputPath = args[1];
	errorIf(!inputPath.exists(), "%s: No such file or directory", inputPath);
	string outputPath = args.length >= 3 ? args[2] : inputPath.setExtension("bin");

	auto tokens = (cast(ubyte[])inputPath.read()).tokenise();
	auto assembler = Assembler(tokens);
	assembler.assemble();

	std.file.write(outputPath, assembler.output);

	if (disassemble)
		["disassembler", outputPath].execute.output.writeln();
}