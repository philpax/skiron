module lexer;

import std.array;
import std.string;
import std.algorithm;
import std.typetuple;
import std.experimental.lexer;

import stringcache;

private:
enum TokOperators =
[
	"<<", ","
];

enum TokDynamic =
[
	"comment", "identifier", "numberLiteral", "label", "whitespace"
];

enum TokKeywords =
[
	"byte", "dbyte", "qbyte"
];

alias AssemblerTokens = TypeTuple!(TokOperators, TokDynamic, TokKeywords);

enum tokenHandlers =
[
	"#", "lexComment",
	"-",  "lexNumber",
	"0",  "lexNumber",
	"1",  "lexNumber",
	"2",  "lexNumber",
	"3",  "lexNumber",
	"4",  "lexNumber",
	"5",  "lexNumber",
	"6",  "lexNumber",
	"7",  "lexNumber",
	"8",  "lexNumber",
	"9",  "lexNumber",
	" ",  "lexWhitespace",
	"\t", "lexWhitespace",
	"\r", "lexWhitespace",
	"\n", "lexWhitespace",
];

public alias TokID = TokenIdType!AssemblerTokens;
public alias tokToString = tokenStringRepresentation!(TokID, AssemblerTokens);
public alias tok(string symbol) = TokenId!(TokID, AssemblerTokens, symbol);

public alias Token = TokenStructure!(TokID,
q{
	import std.array;
	import std.format;
	import std.functional;

	/// Better string representation
	void toString(scope void delegate(const(char)[]) sink) const
	{
		import std.conv;
		import %s;

		if (this.text)
		{
			sink(this.text);
			sink(" (");
			sink(tokToString(this.type));
			sink(")");
		}
		else
		{
			sink(tokToString(this.type));
		}
	}

}.format(__MODULE__));

struct AssemblerLexer
{
	mixin Lexer!(Token, lexIdentifier, isSeparating, AssemblerTokens, tokenHandlers);

	this(ubyte[] source, StringCache* cache)
	{
		this.range = source;
		this.cache = cache;
		popFront();
	}

	/// No additional work here, call Lexer's popFront.
	void popFront() pure
	{
		_popFront();
	}

	void lexWhitespace(ref Token token) pure nothrow
	{
		mixin (tokenStart);
		loop: do
		{
			switch (range.bytes[range.index])
			{
			case '\r':
				range.popFront();
				if (!(range.index >= range.bytes.length) && range.bytes[range.index] == '\n')
				{
					range.popFront();
				}
				range.column = 1;
				range.line += 1;
				break;
			case '\n':
				range.popFront();
				range.column = 1;
				range.line += 1;
				break;
			case ' ':
			case '\t':
				range.popFront();
				break;
			default:
				break loop;
			}
		} while (!(range.index >= range.bytes.length));
		string text = "";
		token = Token(tok!"whitespace", text, line, column, index);
	}

	private pure nothrow @safe:

	/// Token handler
	void lexIdentifier(ref Token token) pure nothrow @safe
	{
		mixin (tokenStart);
		if (isSeparating(0))
		{
			error("Invalid identifier");
			range.popFront();
		}
		while (true)
		{
			if (isSeparating(0))
				break;
			else
				range.popFront();
		}

		TokID type = tok!"identifier";

		if (!range.empty && range.front == ':')
			type = tok!"label";

		token = Token(type, cache.intern(range.slice(mark)), line,
					  column, index);

		if (type == tok!"label")
			range.popFront();
	}

	/// Token handler
	void lexComment(ref Token token) pure nothrow @safe
	{
		mixin (tokenStart); // line, column, index, mark
		range.popFrontN(2);

		while (!range.empty && range.front != '\r' && range.front != '\n')
			range.popFront();

		token = Token(tok!"comment", cache.intern(range.slice(mark)), line, column, index);
	}

	/// Token handler
	void lexNumber(ref Token token) pure nothrow
	{
		mixin (tokenStart); // line, column, index, mark
		if (range.canPeek(1) && range.front == '0')
		{
			auto ahead = range.peek(1)[1];
			switch (ahead)
			{
			case 'x':
			case 'X':
				range.popFront();
				range.popFront();
				token = lexHex(mark, line, column, index);
				return;
			default:
				token = lexDecimal(mark, line, column, index);
				return;
			}
		}
		else
			token = lexDecimal(mark, line, column, index);
	}

	private Token lexHex(size_t mark, size_t line, size_t column, size_t index) pure nothrow
	{
		hexLoop: while (!range.empty)
		{
			switch (range.front)
			{
			case 'a': .. case 'f':
			case 'A': .. case 'F':
			case '0': .. case '9':
				range.popFront();
				break;
			default:
				break hexLoop;
			}
		}
		return Token(tok!"numberLiteral", cache.intern(range.slice(mark)), line, column, index);
	}

	private Token lexDecimal(size_t mark, size_t line, size_t column, size_t index) pure nothrow
	{
		if (range.front == '-')
			range.popFront();

		decimalLoop: while (!range.empty)
		{
			switch (range.front)
			{
			case '0': .. case '9':
				range.popFront();
				break;
			default:
				break decimalLoop;
			}
		}
		return Token(tok!"numberLiteral", cache.intern(range.slice(mark)), line, column, index);
	}

	bool isSeparating(size_t offset) @nogc
	{
		if (!range.canPeek(offset)) return true;
		auto c = range.peekAt(offset);
		if (c == '_') return false;
		if (c >= 'A' && c <= 'Z') return false;
		if (c >= 'a' && c <= 'z') return false;
		if (c >= '0' && c <= '9') return false;
		if (c <= 0x2f) return true;
		if (c >= ':' && c <= '@') return true;
		if (c >= '[' && c <= '^') return true;
		if (c >= '{' && c <= '~') return true;
		if (c == '`' || c == ',') return true;
		return true;
	}

	/// Get all the current info for: line, column, index, mark.
	/// Later we can slice the byte range after N popFront's
	/// by providing the old position (mark) from which to slice
	/// up to the current position.
	enum tokenStart = q{
		size_t line = range.line;
		size_t column = range.column;
		size_t index = range.index;
		auto mark = range.mark();
	};

	void error(string message)
	{
		messages ~= Message(range.line, range.column, message, true);
	}

	void warning(string message)
	{
		messages ~= Message(range.line, range.column, message, false);
		assert (messages.length > 0);
	}

	static struct Message
	{
		size_t line;
		size_t column;
		string message;
		bool isError;
	}

	StringCache* cache;
	Message[] messages;
}

public const(Token)[] tokenise(ubyte[] sourceCode)
{
	StringCache* cache = new StringCache(StringCache.defaultBucketCount);
	string empty = cache.intern("");
	auto output = appender!(typeof(return))();
	auto lexer = AssemblerLexer(sourceCode, cache);
	size_t tokenCount;
	while (!lexer.empty) 
	{
		switch (lexer.front.type)
		{
		case tok!"whitespace":
		case tok!"comment":
		case tok!",":
			lexer.popFront();
			break;
		default:
			Token t = lexer.front;
			lexer.popFront();
			output.put(t);
			break;
		}
	}
	// Insert a whitespace token at the end to signify EOF
	output.put(Token(tok!"", "", 0, 0, 0));
	return output.data;
}