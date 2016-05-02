module common.util.enumdocumented;

import std.string : format;
import std.typecons : tuple;

private template Select(alias IndicesTuple, uint ChunkCount, Args...)
{
	import std.meta : AliasSeq, aliasSeqOf, staticMap;

	static if (Args.length == ChunkCount)
	{
		enum SelectTuple(alias index) = Args[index];
		enum Select = tuple(staticMap!(SelectTuple, aliasSeqOf!([IndicesTuple.expand])));
	}
	else
	{
		enum Select = AliasSeq!(
			Select!(IndicesTuple, ChunkCount, Args[0..ChunkCount]), 
			Select!(IndicesTuple, ChunkCount, Args[ChunkCount..$]));
	}
}

string enumDocumentedDefaultImpl(string Name, Args...)()
{
	string ret;
	
	foreach (value; Select!(tuple(0), 2, Args))
		ret ~= `%s, `.format(value[0]);
	ret ~= "}\n";

	ret ~= "enum " ~ Name ~ "Docs = [";
	foreach (value; Select!(tuple(0, 1), 2, Args))
		ret ~= `tuple(%s.%s, "%s"), `.format(Name, value.expand);
	ret ~= "];\n";

	return ret;
}

string enumDocumentedNonDefaultImpl(string Name, Args...)()
{
	string ret;
	
	foreach (value; Select!(tuple(0, 1), 3, Args))
		ret ~= `%s = %s, `.format(value.expand);
	ret ~= "}\n";

	ret ~= "enum " ~ Name ~ "Docs = [";
	foreach (value; Select!(tuple(0, 2), 3, Args))
		ret ~= `tuple(%s.%s, "%s"), `.format(Name, value.expand);
	ret ~= "];\n";

	return ret;
}

string enumDocumentedImpl(bool UseDefault, string Name, Args...)()
{
	string ret = "enum " ~ Name ~ " { ";

	static if (UseDefault)
		ret ~= enumDocumentedDefaultImpl!(Name, Args);
	else
		ret ~= enumDocumentedNonDefaultImpl!(Name, Args);

	return ret;
}

mixin template EnumDocumented(string Name, Args...)
{
	import std.typecons : tuple;
	mixin(enumDocumentedImpl!(false, Name, Args));
}

mixin template EnumDocumentedDefault(string Name, Args...)
{
	import std.typecons : tuple;
	mixin(enumDocumentedImpl!(true, Name, Args));
}