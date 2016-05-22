module assembler.general;

import std.algorithm;
import std.array;
import std.string;
import std.traits;
import std.conv;

import common.opcode;
import common.cpu;
import common.program;

import assembler.lexer;
import assembler.parse;
import assembler.main;

auto getOpcodeStructureFromFunction(string functionName = __FUNCTION__)()
{
	enum operandFormatStr = functionName.split('.')[$-1]["assemble".length .. $];
	enum operandFormat = __traits(getMember, OperandFormat, operandFormatStr);
	return getOpcodeStructure!(operandFormat);
}

bool assembleDstSrc(ref Assembler assembler, ref const(OpcodeDescriptor) descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1, register2;
	Variant variant;

	if (!assembler.parseOperandSize(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseRegister(newTokens, register2)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	auto opcode = getOpcodeStructureFromFunction();
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.operandSize = operandSize;
	opcode.register1 = register1;
	opcode.register2 = register2;
	opcode.register3 = cast(Register)0;
	opcode.variant = variant;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);

	return true;
}

bool assembleDstSrcSrc(ref Assembler assembler, ref const(OpcodeDescriptor) descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1, register2, register3;
	Variant variant;

	if (!assembler.parseOperandSize(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseRegister(newTokens, register2)) return false;
	if (!assembler.parseRegister(newTokens, register3)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	auto opcode = getOpcodeStructureFromFunction();
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.operandSize = operandSize;
	opcode.register1 = register1;
	opcode.register2 = register2;
	opcode.register3 = register3;
	opcode.variant = variant;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);

	return true;
}

bool assembleDstUimm(ref Assembler assembler, ref const(OpcodeDescriptor) descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1;
	int immediate;
	Variant variant;

	if (!assembler.parseOperandSize(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseNumber(newTokens, immediate)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	auto opcode = getOpcodeStructureFromFunction();
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.register1 = register1;
	opcode.immediate = cast(ushort)immediate;
	opcode.variant = variant;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);

	return true;
}

bool assembleDstSrcImm(ref Assembler assembler, ref const(OpcodeDescriptor) descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1, register2;
	int immediate;
	Variant variant;

	if (!assembler.parseOperandSize(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseRegister(newTokens, register2)) return false;
	if (!assembler.parseNumber(newTokens, immediate)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	auto opcode = getOpcodeStructureFromFunction();
	opcode.operandSize = operandSize;
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.register1 = register1;
	opcode.register2 = register2;
	opcode.immediate = immediate;
	opcode.variant = variant;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);

	return true;
}

bool assembleNone(ref Assembler assembler, ref const(OpcodeDescriptor) descriptor)
{
	auto opcode = getOpcodeStructureFromFunction();
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);

	return true;
}

bool assembleLabel(ref Assembler assembler, ref const(OpcodeDescriptor) descriptor)
{
	auto newTokens = assembler.tokens;

	auto opcode = getOpcodeStructureFromFunction();
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;

	string label;
	if (!assembler.parseLabel(newTokens, label)) return false;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
	{
		assembler.writeOutput(opcode);
		assembler.relocations ~= Assembler.Relocation(
			label, assembler.output.length-1, 
			Assembler.Relocation.Type.Offset);
	}

	return true;
}

bool assemblePseudo(ref Assembler assembler, ref const(OpcodeDescriptor) descriptor, string name)
{
	return assembler.pseudoAssemble[name](assembler, descriptor);
}

void assembleIdentifierToken(ref Assembler assembler, ref const(Token) token)
{
	auto matchingDescriptors = token.text in assembler.descriptors;
	if (!matchingDescriptors)
		token.error("No matching opcode found for `%s`.", token.text);

	assembler.tokens.popFront();

	foreach (descriptor; *matchingDescriptors)
	{
		foreach (member; EnumMembers!OperandFormat)
		{
			static if (member.name != OperandFormat.Pseudo.name)
			{
				if (descriptor.operandFormat.name == member.name)
				{
					if (mixin("assemble" ~ member.to!string())(assembler, descriptor))
						return;
				}
			}
		}

		if (descriptor.operandFormat.name == OperandFormat.Pseudo.name)
		{
			if (assemblePseudo(assembler, descriptor, token.text))
				return;
		}
	}

	token.error("No valid overloads for `%s` found.", token.text);
}

void assembleLabelToken(ref Assembler assembler, ref const(Token) token)
{
	assembler.labels[token.text] = assembler.getEndOffset();
	assembler.tokens.popFront();
}

void assembleSectionToken(ref Assembler assembler, ref const(Token) token)
{
	if (assembler.sections.length)
		assembler.sections[$-1].end = assembler.getEndOffset();

	if (token.text.length >= ProgramSection.NameLength)
		token.error("Section name `%s` too long.", token.text);

	ProgramSection section;
	section.name = token.text;
	section.begin = assembler.getEndOffset();
	assembler.sections ~= section;

	assembler.tokens.popFront();
}