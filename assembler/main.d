import std.exception;
import std.stdio;
import std.file;
import std.ascii;
import std.string;
import std.conv;
import std.traits;
import std.algorithm;
import std.array;
import std.path;

import core.stdc.stdlib;

import common.opcode;
import common.cpu;

struct Token
{
	enum Type
	{
		Identifier,
		Number,
		Register,
		Label,
		Byte,
		Dbyte,
		Qbyte
	}

	string fileName;
	int lineNumber;
	int column;

	Type type;
	string text;
	int number;

	string toString()
	{
		return "%s:%s".format(type, text);
	}
}

OpcodeDescriptor[][string] descriptors;

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

void error(Args...)(ref Token token, string text, auto ref Args args)
{
	writef("%s[%s,%s]: ", token.fileName, token.lineNumber, token.column);
	error(text, args);
}

void attemptTokeniseRegister(ref Token token)
{
	auto t = token.text;
	if (t == "ip")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.IP;
		return;
	}
	else if (t == "sp")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.SP;
		return;
	}
	else if (t == "bp")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.BP;
		return;
	}
	else if (t == "z")
	{
		token.type = Token.Type.Register;
		token.number = cast(int)Register.Z;
		return;
	}
	else if (t.startsWith("r") && t.length > 1 && t[1..$].all!isDigit)
	{
		token.type = Token.Type.Register;
		token.number = t[1..$].to!ubyte();
		return;
	}
}

Token[] tokenise(string input, string fileName)
{
	Token[] tokens;
	Token currentToken;

	int lineNumber = 0;
	int column = 0;

	void makeToken()
	{
		currentToken = Token();
		currentToken.fileName = fileName;
	}

	makeToken();

	void completeToken()
	{
		if (currentToken.text.length == 0)
			return;

		if (currentToken.type == Token.Type.Number)
			currentToken.number = currentToken.text.to!int();
		else if (currentToken.type == Token.Type.Identifier)
		{
			if (currentToken.text == "byte")
				currentToken.type = Token.Type.Byte;
			else if (currentToken.text == "dbyte")
				currentToken.type = Token.Type.Dbyte;
			else if (currentToken.text == "qbyte")
				currentToken.type = Token.Type.Qbyte;
			else
				currentToken.attemptTokeniseRegister();
		}

		currentToken.lineNumber = lineNumber;

		tokens ~= currentToken;
		makeToken();
	}

	bool lexingComment = false;
	foreach (line; input.lineSplitter)
	{
		++lineNumber;
		column = 0;

		lexingComment = false;
		currentToken.lineNumber = lineNumber;
		foreach (c; line)
		{
			++column;
			currentToken.column = column;

			if (lexingComment)
				break;

			if (c.isWhite())
			{
				completeToken();
			}
			else if (c == '#')
			{
				lexingComment = true;
			}
			else if (currentToken.text.length == 0 && (c.isDigit() || c == '-'))
			{
				currentToken.type = Token.Type.Number;
				currentToken.text ~= c;
			}
			else if (currentToken.type == Token.Type.Number)
			{
				if (!c.isDigit())
					currentToken.error("Expected digit; got `%s`.", c);
				currentToken.text ~= c;
			}
			else if (currentToken.type == Token.Type.Identifier && c.isAlphaNum())
			{
				currentToken.text ~= c;
			}
			else if (currentToken.type == Token.Type.Identifier && c == ':')
			{
				currentToken.type = Token.Type.Label;
			}
			else if (c == ',')
			{
				continue;
			}
			else
			{
				currentToken.error("Invalid character `%s` for token `%s`", c, currentToken.to!string());
			}
		}
		completeToken();
	}

	return tokens;
}

int parseNumber(ref Token[] tokens)
{
	auto token = tokens.front;
	enforce(token.type == Token.Type.Number);

	scope (success) tokens.popFront();
	return token.number;
}

OperandSize parseSizePrefix(ref Token[] tokens)
{
	auto token = tokens.front;

	if (token.type == Token.Type.Byte)
	{
		tokens.popFront();
		return OperandSize.Byte;
	}
	else if (token.type == Token.Type.Dbyte)
	{
		tokens.popFront();
		return OperandSize.Dbyte;
	}
	else if (token.type == Token.Type.Qbyte)
	{
		tokens.popFront();
		return OperandSize.Qbyte;
	}
	else
	{
		return OperandSize.Qbyte;
	}
}

ubyte parseRegister(ref Token[] tokens)
{
	scope (success) tokens.popFront();
	auto token = tokens.front;
	enforce(token.type == Token.Type.Register);

	return cast(ubyte)token.number;
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
	opcode.x = cast(ubyte)newTokens.parseSizePrefix();
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
	uint[string] labels;
	while (!tokens.empty)
	{
		auto token = tokens.front;

		if (token.type == Token.Type.Identifier)
		{
			auto descriptors = token.text in descriptors;
			if (!descriptors)
				token.error("No matching opcode found for `%s`.", token.text);

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
			if (!foundMatching)
				token.error("No valid overloads for `%s` found.", token.text);
		}
		else if (token.type == Token.Type.Label)
		{
			auto text = token.text;
			if (text in labels)
				token.error("Redefining label `%s`", text);
			labels[text] = cast(uint)output.length;
			tokens.popFront();
		}
		else
		{
			token.error("Unhandled token: %s.", token.to!string());
		}
	}

	return output;
}

void main(string[] args)
{
	errorIf(args.length < 2, "expected at least one argument");
	string inputPath = args[1];
	errorIf(!inputPath.exists(), "%s: No such file or directory", inputPath);
	string outputPath = args.length >= 3 ? args[2] : inputPath.setExtension("bin");

	auto input = inputPath.readText();

	foreach (member; EnumMembers!Opcodes)
		descriptors[member.name] ~= member;

	auto tokens = input.tokenise(inputPath);
	auto output = tokens.assemble();

	std.file.write(outputPath, output);
}