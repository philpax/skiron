import std.exception;
import std.stdio;
import std.file;
import std.ascii;
import std.string;
import std.conv;
import std.traits;

import common.opcode;

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

Token[] tokenise(string input)
{
	Token[] tokens;
	Token currentToken;
	foreach (c; input)
	{
		if (c.isWhite() && currentToken.text.length > 0)
		{
			if (currentToken.type == Token.Type.Number)
				currentToken.number = currentToken.text.to!int();

			tokens ~= currentToken;
			currentToken = Token();
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

	return tokens;
}

void main(string[] args)
{
	enforce(args.length >= 3, "Expected at least two arguments");
	auto input = args[1].readText();

	OpcodeDescriptor[][string] descriptors;
	foreach (member; EnumMembers!Opcodes)
		descriptors[member.name] ~= member;
	writeln(descriptors);

	writeln(input.tokenise());
}