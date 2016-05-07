module assembler.parse;

import std.algorithm;
import std.array;
import std.conv;

import common.opcode;
import common.cpu;

import assembler.lexer;
import assembler.main;

bool parseNumber(Int)(ref Assembler assembler, ref const(Token)[] tokens, ref Int output)
	if (is(Int : int))
{
	auto token = tokens.front;
	if (token.type != tok!"numberLiteral")
		return false;

	auto text = token.text;
	if (text.startsWith("0x"))
		output = cast(Int)text[2..$].to!long(16);
	else
		output = cast(Int)text.to!long;
	tokens.popFront();
	return true;
}

bool parseOperandSize(ref Assembler assembler, ref const(Token)[] tokens, ref OperandSize output)
{
	auto token = tokens.front;

	if (token.type == tok!"byte" || token.type == tok!"byte1")
	{
		tokens.popFront();
		output = OperandSize.Byte;
	}
	else if (token.type == tok!"byte2")
	{
		tokens.popFront();
		output = OperandSize.Byte2;
	}
	else if (token.type == tok!"byte4" || token.type == tok!"word")
	{
		tokens.popFront();
		output = OperandSize.Byte4;
	}
	else
	{
		output = OperandSize.Byte4;
	}

	return true;
}

bool parseRegister(ref Assembler assembler, ref const(Token)[] tokens, ref Register output)
{
	auto token = tokens.front;
	if (token.type != tok!"identifier")
		return false;

	try
	{
		output = token.text.registerFromName();
	}
	catch (Exception)
	{
		return false;
	}

	tokens.popFront();
	return true;
}

bool parseLabel(ref Assembler assembler, ref const(Token)[] tokens, ref string output)
{
	auto token = tokens.front;
	if (token.type != tok!"identifier")
		return false;

	auto ptr = token.text in assembler.labels;
	if (!ptr)
		return false;

	output = token.text;
	tokens.popFront();

	return true;
}

bool parseVariant(ref Assembler assembler, ref const(Token)[] tokens, ref Variant output)
{
	Token token = tokens.front;

	if (token.type == tok!"<<")
	{
		tokens.popFront();

		int shift;
		if (!assembler.parseNumber(tokens, shift))
		{
			token.error("Expected number in shift");
			return false;
		}

		if (shift == 1)
		{
			output = Variant.ShiftLeft1;
		}
		else if (shift == 2)
		{
			output = Variant.ShiftLeft2;
		}
		else
		{
			token.error("Shift size not encodable");
			return false;
		}
	}
	else
	{
		// TODO: Look into why exactly Variant.Default doesn't work
		output = cast(Variant)0;
	}

	return true;
}

void finishAssemble(ref Assembler assembler, const(Token)[] tokens)
{
	assembler.tokens = tokens;
	assembler.repCount = 1;
}
