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

ubyte parseRegister(ref Token[] tokens)
{
	auto token = tokens.front;
	enforce(token.type == Token.Type.Identifier);

	scope (success) tokens.popFront();

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
	else
		throw new Exception("Invalid register: " ~ t);
}

int parseNumber(ref Token[] tokens)
{
	auto token = tokens.front;
	enforce(token.type == Token.Type.Number);

	scope (success) tokens.popFront();
	return token.number;
}

bool assembleDstSrc(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	auto newTokens = tokens;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	try
	{
		opcode.register1 = newTokens.parseRegister();
		opcode.register2 = newTokens.parseRegister();
		opcode.register3 = 0;
	}
	catch (Exception e)
		return false;

	output ~= opcode.value;
	tokens = newTokens;

	return true;
}

bool assembleDstSrcSrc(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	auto newTokens = tokens;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	try
	{
		opcode.register1 = newTokens.parseRegister();
		opcode.register2 = newTokens.parseRegister();
		opcode.register3 = newTokens.parseRegister();
	}
	catch (Exception e)
		return false;

	output ~= opcode.value;
	tokens = newTokens;

	return true;
}

bool assembleDstImm(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	auto newTokens = tokens;

	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	try
	{
		opcode.register1 = newTokens.parseRegister();
		opcode.immediate = newTokens.parseNumber();
	}
	catch (Exception e)
		return false;

	output ~= opcode.value;
	tokens = newTokens;

	return true;
}

bool assembleNone(ref Token[] tokens, ref const(OpcodeDescriptor) descriptor, ref uint[] output)
{
	Opcode opcode;
	opcode.opcode = descriptor.opcode;
	output ~= opcode.value;

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

			tokens.popFront();
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
			enforce(foundMatching, "No valid overloads for '" ~ token.text ~ "' found");
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