module emulator.core;

public import common.cpu;
public import common.opcode;

import common.debugging;

import emulator.state;

import emulator.instruction.memory;
import emulator.instruction.arithmetic;
import emulator.instruction.controlflow;

string generateOpcodeSwitch()
{
	import std.traits, std.string, std.conv;
	string s = 
`final switch (opcode.opcode)
{
`;
	foreach (member; EnumMembers!Opcodes)
	{
		if (member.operandFormat == OperandFormat.Pseudo)
			continue;

		if (OperandFormatToOperandSizeSupport[member.operandFormat])
		{
			s ~= format(
`case Opcodes.%1$s.opcode:
	final switch (opcode.operandSize)
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

@nogc:
nothrow:

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

	@property ref uint ip()
	{
		return this.registers[Register.IP];
	}

	@property ref uint sp()
	{
		return this.registers[Register.SP];
	}

	@property ref uint bp()
	{
		return this.registers[Register.BP];
	}

	@property ref uint ra()
	{
		return this.registers[Register.RA];
	}

	@property ref uint flags()
	{
		return this.registers[Register.Flags];
	}

	void step()
	{
		if (this.paused && !this.doStep)
			return;

		auto opcode = Opcode(*cast(uint*)&this.memory[this.ip]);
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
	return cast(Type)core.registers[opcode.register1];
}

void setDst(Type = uint, IncomingType)(ref Core core, Opcode opcode, IncomingType value)
{
	if (opcode.register1 == Register.Z)
		return;
	else
		*cast(Type*)&core.registers[opcode.register1] = cast(Type)value;
}

Type doVariant(Type = uint)(Opcode opcode, Type value)
{
	final switch (opcode.variant)
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
	final switch (opcode.encoding)
	{
		case Encoding.A:
			assert(0);
		case Encoding.B:
			return opcode.doVariant(opcode.immediateB);
		case Encoding.C:
			return opcode.doVariant(opcode.immediateC);
		case Encoding.D:
			return opcode.doVariant(opcode.immediateD);
	}
}

Type getSrc(Type = uint)(ref Core core, Opcode opcode)
{
	return opcode.doVariant(cast(Type)core.registers[opcode.register2]);
}

Type getSrc1(Type = uint)(ref Core core, Opcode opcode)
{
	return cast(Type)core.registers[opcode.register2];
}

Type getSrc2(Type = uint)(ref Core core, Opcode opcode)
{
	return opcode.doVariant(cast(Type)core.registers[opcode.register3]);
}