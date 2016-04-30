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

bool assembleDstSrc(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1, register2;
	Variant variant;
	if (!assembler.parseSizePrefix(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseRegister(newTokens, register2)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.operandSize = operandSize;
	opcode.register1 = register1;
	opcode.register2 = register2;
	opcode.register3 = cast(Register)0;
	opcode.variant = variant;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);
	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleDstSrcSrc(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1, register2, register3;
	Variant variant;
	if (!assembler.parseSizePrefix(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseRegister(newTokens, register2)) return false;
	if (!assembler.parseRegister(newTokens, register3)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.operandSize = operandSize;
	opcode.register1 = register1;
	opcode.register2 = register2;
	opcode.register3 = register3;
	opcode.variant = variant;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);
	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleDstUImm(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1;
	int immediate;
	Variant variant;
	if (!assembler.parseSizePrefix(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseNumber(newTokens, immediate)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.register1 = register1;
	opcode.immediateB = cast(ushort)immediate;
	opcode.variant = variant;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);
	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleDstSrcImm(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register1, register2;
	int immediate;
	Variant variant;
	if (!assembler.parseSizePrefix(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register1)) return false;
	if (!assembler.parseRegister(newTokens, register2)) return false;
	if (!assembler.parseNumber(newTokens, immediate)) return false;
	if (!assembler.parseVariant(newTokens, variant)) return false;

	Opcode opcode;
	opcode.operandSize = operandSize;
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;
	opcode.register1 = register1;
	opcode.register2 = register2;
	opcode.immediateD = immediate;
	opcode.variant = variant;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);
	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleNone(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(opcode);

	return true;
}

bool assembleLabel(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.encoding = descriptor.encoding;

	string label;
	if (!assembler.parseLabel(newTokens, label)) return false;

	foreach (_; 0..assembler.repCount)
	{
		assembler.writeOutput(opcode);
		assembler.relocations ~= Assembler.Relocation(
			label, assembler.output.length-1, 
			Assembler.Relocation.Type.Offset);
	}
	assembler.finishAssemble(newTokens);

	return true;
}

void assembleIdentifierToken(ref Assembler assembler, ref const(Token) token)
{
	auto matchingDescriptors = token.text in assembler.descriptors;
	if (!matchingDescriptors)
		token.error("No matching opcode found for `%s`.", token.text);

	bool foundMatching = false;

	string generateSwitchStatement()
	{
		string s =
`final switch (descriptor.operandFormat)
{
`;
		foreach (member; EnumMembers!OperandFormat)
		{
			if (member == OperandFormat.Pseudo)
				continue;

			s ~= format(
`case OperandFormat.%1$s:
	foundMatching |= assembler.assemble%1$s(&descriptor);
	break;
`,
			member.to!string());
		}

		s ~=
`case OperandFormat.Pseudo:
	foundMatching |= assembler.pseudoAssemble[token.text](assembler, &descriptor);
	break;
}
`;
		return s;
	}

	assembler.tokens.popFront();
	foreach (descriptor; *matchingDescriptors)
	{
		mixin (generateSwitchStatement());

		if (foundMatching)
			break;
	}
	if (!foundMatching)
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
		token.error("Token name `%s` too long.", token.text);

	ProgramSection section;
	section.name = token.text;
	section.begin = assembler.getEndOffset();
	assembler.sections ~= section;

	assembler.tokens.popFront();
}