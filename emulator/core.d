module emulator.core;

public import common.cpu;
public import common.opcode;

import common.debugging;

import emulator.state;
import emulator.instruction;

import std.traits : EnumMembers;
import std.algorithm : map;
import std.conv : to;
import std.string : format, join;

string generateOpcodeRunners()
{
	import std.array : empty;
	import std.string : replace;

	enum sizedTemplate = q{
	void run%s(Type = uint)(ref Core core, Opcode opcode)
	{
		%s;
	}
};

	string ret;

	foreach (member; EnumMembers!Opcodes)
	{
		if (member.operation.empty)
			continue;

		auto operation = member.operation.replace("dst =", "core.dst!Type(opcode) = cast(Type)(")
										 .replace("src1", "core.getSrc1!Type(opcode)")
										 .replace("src2", "core.getSrc2!Type(opcode)");

		operation ~= ")";
		ret ~= sizedTemplate.format(member.to!string(), operation);
	}

	return ret;
}

string generateOpcodeSwitch()
{
	string s = 
`final switch (opcode.a.opcode)
{
`;
	foreach (member; EnumMembers!Opcodes)
	{
		if (member.operandFormat == OperandFormat.Pseudo)
			continue;

		if (member.operandFormat.supportsOperandSize)
		{
			s ~= format(
`case Opcodes.%1$s.opcode:
	final switch (opcode.a.operandSize)
	{
		case OperandSize.Byte:
			this.run%1$s!ubyte(opcode);
			break;
		case OperandSize.Byte2:
			this.run%1$s!ushort(opcode);
			break;
		case OperandSize.Byte4:
			this.run%1$s!uint(opcode);
			break;
	}
	break;
`, 
			member.to!string());
		}
		else
		{
			s ~= format(
`case Opcodes.%1$s.opcode:
	this.run%1$s(opcode);
	break;
`, 
			member.to!string());
		}
	}
	s ~= "}\n";
	return s;
}

string generateRegisterProperties()
{
	import std.uni : toLower;

	return [EnumMembers!Register].map!((a) {
		return
`	@property ref uint %s()
	{
		return this.registers[Register.%s];
	}
`.format(a.to!string.toLower(), a.to!string());
	}).join('\n');
}

@nogc:
nothrow:

mixin(generateOpcodeRunners());

struct Core
{
@nogc:
nothrow:
	State* state;
	ubyte[] memory;
	RegisterType[RegisterExtendedCount] registers;
	bool running = true;
	
	// Changed by debugger
	bool paused = false;
	bool doStep = false;

	uint id;

	@disable this();
	this(ref State state, uint id, bool paused)
	{
		this.state = &state;
		this.memory = state.memory;
		this.id = id;
		this.paused = paused;
	}

	~this() {}

	mixin(generateRegisterProperties());

	void step()
	{
		if (this.paused && !this.doStep)
			return;

		auto opcode = *cast(Opcode*)&this.memory[this.ip];
		this.ip += uint.sizeof;

		mixin(generateOpcodeSwitch());

		if (this.doStep)
		{
			this.sendState();
			this.doStep = false;
		}
	}

	void sendState()
	{
		this.state.sendMessage!CoreState(this.id, !this.paused && this.running, this.registers);
	}
}

Type getDst(Type = uint)(ref Core core, Opcode opcode)
{
	if (opcode.a.register1 == Register.Z)
		return cast(Type)0;

	return core.dst!Type(opcode);
}

ref Type dst(Type = uint)(ref Core core, Opcode opcode)
{
	return *cast(Type*)&core.registers[opcode.a.register1];
}

Type doVariant(Type = uint)(Opcode opcode, Type value)
{
	final switch (opcode.a.variant)
	{
		case Variant.Identity:
			return value;
		case Variant.ShiftLeft1:
			return cast(Type)(value << 1);
		case Variant.ShiftLeft2:
			return cast(Type)(value << 2);
	}
}

int getImmediate(ref Core core, Opcode opcode)
{
	final switch (opcode.a.encoding)
	{
		case Encoding.A:
			assert(0);
		case Encoding.B:
			return opcode.doVariant(opcode.b.immediate);
		case Encoding.C:
			return opcode.doVariant(opcode.c.immediate);
		case Encoding.D:
			return opcode.doVariant(opcode.d.immediate);
	}
}

Type getSrc(Type = uint)(ref Core core, Opcode opcode)
{
	return opcode.doVariant(cast(Type)core.registers[opcode.a.register2]);
}

Type getSrc1(Type = uint)(ref Core core, Opcode opcode)
{
	return cast(Type)core.registers[opcode.a.register2];
}

Type getSrc2(Type = uint)(ref Core core, Opcode opcode)
{
	return opcode.doVariant(cast(Type)core.registers[opcode.a.register3]);
}