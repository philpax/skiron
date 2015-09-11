import std.exception;
import std.stdio;
import std.file;
import std.ascii;
import std.string;
import std.conv;
import std.traits;
import std.algorithm;
import std.array;

import common.opcode;
import common.cpu;

struct Token
{
	enum Type
	{
		Identifier,
		Number
	}

	Type type;
	string text;
	int number;
}

OpcodeDescriptor[][string] descriptors;

Token[] tokenise(string input)
{
	Token[] tokens;
	Token currentToken;

	void completeToken()
	{
		if (currentToken.text.length == 0)
			return;

		if (currentToken.type == Token.Type.Number)
			currentToken.number = currentToken.text.to!int();

		tokens ~= currentToken;
		currentToken = Token();
	}

	foreach (c; input)
	{
		if (c.isWhite())
		{
			completeToken();
		}
		else if (currentToken.text.length == 0 && (c.isDigit() || c == '-'))
		{
			currentToken.type = Token.Type.Number;
			currentToken.text ~= c;
		}
		else if (currentToken.type == Token.Type.Number)
		{
			enforce(c.isDigit(), "Expected a number while lexing %s; got %s".format(currentToken.to!string(), c));
			currentToken.text ~= c;
		}
		else if (currentToken.type == Token.Type.Identifier && c.isAlphaNum())
		{
			currentToken.text ~= c;
		}
	}
	completeToken();

	return tokens;
}

ubyte toRegister(Token token)
{
	auto t = token.text;
	if (t == "ip")
		return Register.IP;
	else if (t == "sp")
		return Register.SP;
	else if (t == "bp")
		return Register.BP;
	else if (t == "z")
		return Register.Z;
	else if (t.startsWith("r"))
		return t[1..$].to!ubyte();

	assert(0);
}

bool assembleDstSrc(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	if (tokens.length < 3)
		return false;

	auto operandTokens = tokens[1..3];
	if (operandTokens.any!(a => a.type != Token.Type.Identifier))
		return false;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.register1 = operandTokens[0].toRegister();
	opcode.register2 = operandTokens[1].toRegister();
	opcode.register3 = 0;

	output ~= opcode.value;

	tokens = tokens[3..$];
	return true;
}

bool assembleDstSrcSrc(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	if (tokens.length < 4)
		return false;

	auto operandTokens = tokens[1..4];
	if (operandTokens.any!(a => a.type != Token.Type.Identifier))
		return false;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.register1 = operandTokens[0].toRegister();
	opcode.register2 = operandTokens[1].toRegister();
	opcode.register3 = operandTokens[2].toRegister();

	output ~= opcode.value;

	tokens = tokens[4..$];
	return true;
}

bool assembleDstImm(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	if (tokens.length < 3)
		return false;

	auto operandTokens = tokens[1..3];
	if (operandTokens[0].type != Token.Type.Identifier ||
		operandTokens[1].type != Token.Type.Number)
		return false;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.register1 = operandTokens[0].toRegister();
	opcode.immediate = operandTokens[1].number;

	output ~= opcode.value;

	tokens = tokens[3..$];
	return true;
}

bool assembleNone(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	if (tokens.length < 1)
		return false;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	opcode.register1 = 0;
	opcode.immediate = 0;

	output ~= opcode.value;

	tokens = tokens[1..$];
	return true;
}

uint[] assemble(Token[] tokens)
{
	uint[] output;
	while (!tokens.empty)
	{
		auto token = tokens.front;

		if (token.type == Token.Type.Identifier)
		{
			auto descriptors = token.text in descriptors;
			enforce(descriptors, "No matching opcode found for " ~ token.text);
			bool foundMatching = false;
			foreach (descriptor; *descriptors)
			{
				if (descriptor.operandFormat == OperandFormat.DstSrc)
				{
					if (tokens.assembleDstSrc(descriptor, output))
					{
						foundMatching = true;
						break;
					}
				}
				else if (descriptor.operandFormat == OperandFormat.DstSrcSrc)
				{
					if (tokens.assembleDstSrcSrc(descriptor, output))
					{
						foundMatching = true;
						break;
					}
				}
				else if (descriptor.operandFormat == OperandFormat.DstImm)
				{
					if (tokens.assembleDstImm(descriptor, output))
					{
						foundMatching = true;
						break;
					}
				}
				else if (descriptor.operandFormat == OperandFormat.None)
				{
					if (tokens.assembleNone(descriptor, output))
					{
						foundMatching = true;
						break;
					}
				}
			}
			enforce(foundMatching, "No valid opcodes found");
		}
		else
		{
			enforce(false, "Unhandled token: " ~ token.to!string());
		}
	}

	return output;
}

void main(string[] args)
{
	enforce(args.length >= 3, "Expected at least two arguments");
	auto input = args[1].readText();

	foreach (member; EnumMembers!Opcodes)
		descriptors[member.name] ~= member;

	auto tokens = input.tokenise();
	auto output = tokens.assemble();

	std.file.write(args[2], output);
}