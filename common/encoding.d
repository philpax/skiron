module common.encoding;

import std.bitmanip;
import std.meta;

struct EncodingDescription
{
	struct Field
	{
		string type;
		string name;
		int size;
		string description;
	}

	string name;
	string description;
	Field[] fields;
}

private:
string removeUnderscored(string s)
{
	if (s.length && s[0] == '_')
		return "";
	else
		return s;
}

template encodingFilter(Args...)
{
	static if (Args.length > 4)
		alias encodingFilter = AliasSeq!(encodingFilter!(Args[0..4]), encodingFilter!(Args[4..$]));
	else
		alias encodingFilter = AliasSeq!(Args[0], removeUnderscored(Args[1]), Args[2]);
}

string encodingDocsMake(Args...)()
{
	import std.string : format;

	static if (Args.length)
	{
		auto name = Args[1];

		if (name[0] == '_')
			name = name[1..$];

		return `EncodingDescription.Field("%s", "%s", %s, "%s"), `.format(Args[0].stringof, name, Args[2], Args[3]) ~ encodingDocsMake!(Args[4..$]);
	}
	else
	{
		return ``;
	}
}

string encodingDocs(string Name, string Description, Args...)()
{
	import std.string : format;

	auto ret = `enum EncodingSeq` ~ Name ~ ` = EncodingDescription(`;
	ret ~= `"%s", "%s", [`.format(Name, Description);
	ret ~= encodingDocsMake!(Args);
	ret ~= "]);\n";
	return ret;
}

public:
string defineEncoding(string Name, string Description, Args...)()
{
	auto ret = bitfields!(encodingFilter!Args);
	ret ~= encodingDocs!(Name, Description, Args);
	return ret;
}

mixin template DefineEncoding(string Name, string Description, Args...)
{
	mixin(defineEncoding!(Name, Description, Args));
}