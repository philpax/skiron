module docgen.encodings;

import std.stdio;
import std.string : format, join, empty;
import std.conv : to;
import std.algorithm : map, filter;

import common.opcode;
import common.encoding;
import common.cpu;

void writeEncodingList(ref File file)
{
	string[string] fieldDescriptions;
	foreach (encodingDescriptor; getEncodings!Opcode())
	{
		file.writefln("## Encoding %s", encodingDescriptor.name);
		file.writeln(encodingDescriptor.description);
		file.writeln();

		file.writeln("### Field Layout");
		file.writeln(encodingDescriptor.fields.map!(a => "%s bits".format(a.size)).join(" | "));
		file.writeln(encodingDescriptor.fields.map!(a => "---").join(" | "));
		file.writeln(encodingDescriptor.fields.map!(a => '`' ~ a.name ~ '`').join(" | "));
		file.writeln();

		foreach (field; encodingDescriptor.fields)
		{
			auto description = field.description;

			if (field.name !in fieldDescriptions)
				fieldDescriptions[field.name] = description;
			else if (description.empty)
				description = fieldDescriptions[field.name];

			file.writef("* `%s` (`%s`, %s bits)", field.name, field.type, field.size);

			if (description.length)
				file.writef(": %s", description);

			file.writeln();
		}

		file.writeln();
	}
}

void writeVariants(ref File file)
{
	file.writeln("## Variants");
	file.writeln(
		"The last argument of an instruction can be modified by a Variant before " ~ 
		"being used in a computation.");
	file.writeln();

	foreach (pair; VariantDocs)
	{
		file.writefln("* **%s**", pair[0].to!string());
		file.writefln("    * *Index*: %s", cast(uint)pair[0]);
		file.writefln("    * *Description*: %s", pair[1]);
	}

	file.writeln();
}

void writeOperandFormats(ref File file)
{
	file.writeln("## Operand Formats");
	file.writeln(
		"An opcode has an operand format, which specifies which arguments it takes.");
	file.writeln();

	foreach (pair; OperandFormatDocs)
	{
		file.writefln("* **%s**", pair[0].to!string());
		file.writefln("    * *Index*: %s", cast(uint)pair[0]);
		file.writefln("    * *Description*: %s", pair[1]);
	}
}

string writeEncodings()
{
	const filename = "Opcode-Encoding.md";
	auto file = File(filename, "w");

	file.writeEncodingList();	
	file.writeVariants();
	file.writeOperandFormats();

	return filename;
}