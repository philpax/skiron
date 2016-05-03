module common.util.sformat;

private size_t autoFormat(FmtArgs...)(char[] buffer, size_t index, const(char)* fmt, FmtArgs fmtArgs)
{
	import core.stdc.stdio : snprintf;
	import core.stdc.string : memcpy;
	import std.algorithm : min;
	import common.util.stackbuffer : StackBuffer;

	StackBuffer!1024 argBuffer;
	argBuffer.allocate(snprintf(null, 0, fmt, fmtArgs));

	auto size = snprintf(cast(char*)argBuffer.ptr, argBuffer.length, fmt, fmtArgs);
	memcpy(buffer.ptr + index, argBuffer.ptr, min(argBuffer.length, buffer.length - index));
	return size;
}

char[] sformat(Args...)(string format, char[] buffer, Args args) @nogc nothrow
{
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

				foreach (arg; args)
				{
					if (argumentIndex != currentIndex)
						continue;

					static if (is(typeof(arg) : int))
						index += buffer.autoFormat(index, "%i", arg);
					else static if (is(typeof(arg) == string))
						index += buffer.autoFormat(index, "%.*s", arg.length, arg.ptr);
					else static if (is(typeof(arg) : const(char[])))
						index += buffer.autoFormat(index, "%.*s", arg.length, arg.ptr);

					++currentIndex;
				}

				++argumentIndex;
			}
			else if (c == '%')
			{
				buffer[index] = '%';
				++index;
			}

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
		}

		if (index >= buffer.length)
			return buffer;
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