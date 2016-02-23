module common.util;

char[] sformat(Args...)(string format, char[] buffer, Args args) @nogc nothrow
{
	import core.stdc.stdio;

	size_t index = 0;
	size_t argumentIndex = 0;
	bool parsingFormatString;
	foreach (c; format)
	{
		if (parsingFormatString)
		{
			if (c == 's')
			{
				size_t currentIndex = 0;

				void autoFormat(FmtArgs...)(const(char)* fmt, FmtArgs fmtArgs)
				{
					import core.stdc.string : memcpy;
					import std.algorithm : min;

					char[1024] argBuffer;

					auto size = snprintf(argBuffer.ptr, argBuffer.length, fmt, fmtArgs);
					memcpy(buffer.ptr + index, argBuffer.ptr, min(argBuffer.length, buffer.length - index));
					index += size;
				}

				foreach (arg; args)
				{
					if (argumentIndex == currentIndex)
					{
						static if (is(typeof(arg) : int))
							autoFormat("%i", arg);
						else static if (is(typeof(arg) == string))
							autoFormat("%.*s", arg.length, arg.ptr);
						else static if (is(typeof(arg) : const(char[])))
							autoFormat("%.*s", arg.length, arg.ptr);
					}

					++currentIndex;
				}
				++argumentIndex;
			}
			else if (c == '%')
			{
				buffer[index] = '%';
				++index;
			}

			if (index >= buffer.length)
				return buffer;

			parsingFormatString = false;
		}
		else
		{
			if (c == '%')
			{
				parsingFormatString = true;
				continue;
			}

			buffer[index] = c;
			++index;

			if (index >= buffer.length)
				return buffer;
		}
	}

	return buffer[0..index];
}

unittest
{
	import std.stdio;

	char[16] buffer;
	assert("Testing 123".sformat(buffer) == "Testing 123");
	assert("Testing %s".sformat(buffer, 123456) == "Testing 123456");
	assert("Testing %s %s".sformat(buffer, 123456, "Testing") == "Testing 123456 T");
	assert("r%s".sformat(buffer, cast(ubyte)5) == "r5");
}