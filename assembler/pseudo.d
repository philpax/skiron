module assembler.pseudo;

import std.math;
import std.array;

import common.opcode;
import common.cpu;

import assembler.main;
import assembler.parse;

void assemblePushManual(ref Assembler assembler, Register register, OperandSize operandSize = OperandSize.Byte4)
{
	// Synthesize add, store
	Opcode add;
	add.opcode = Opcodes.AddD.opcode;
	add.encoding = Opcodes.AddD.encoding;
	add.operandSize = OperandSize.Byte4;
	add.register1 = Register.SP;
	add.register2 = Register.SP;
	add.immediateD = -4;

	Opcode store;
	store.opcode = Opcodes.Store.opcode;
	store.encoding = Opcodes.Store.encoding;
	store.operandSize = operandSize;
	store.register1 = Register.SP;
	store.register2 = register;

	assembler.writeOutput(add);
	assembler.writeOutput(store);
}

bool assemblePush(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register;
	if (!assembler.parseSizePrefix(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register)) return false;

	foreach (_; 0..assembler.repCount)
		assembler.assemblePushManual(register, operandSize);

	assembler.finishAssemble(newTokens);

	return true;
}

void assemblePopManual(ref Assembler assembler, Register register, OperandSize operandSize = OperandSize.Byte4)
{
	// Synthesize load, add
	Opcode load;
	load.opcode = Opcodes.Load.opcode;
	load.encoding = Opcodes.Load.encoding;
	load.operandSize = operandSize;
	load.register1 = register;
	load.register2 = Register.SP;

	Opcode add;
	add.opcode = Opcodes.AddD.opcode;
	add.encoding = Opcodes.AddD.encoding;
	add.operandSize = OperandSize.Byte4;
	add.register1 = Register.SP;
	add.register2 = Register.SP;
	add.immediateD = 4;

	assembler.writeOutput(load);
	assembler.writeOutput(add);
}

bool assemblePop(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register register;
	if (!assembler.parseSizePrefix(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, register)) return false;

	foreach (_; 0..assembler.repCount)
		assembler.assemblePopManual(register, operandSize);

	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleCallSv(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	Opcode call;
	call.opcode = Opcodes.Call.opcode;
	call.encoding = Opcodes.Call.encoding;

	string label;
	if (!assembler.parseLabel(newTokens, label)) return false;

	foreach (_; 0..assembler.repCount)
	{
		assembler.assemblePushManual(Register.RA);
			
		assembler.writeOutput(call);
		assembler.relocations ~= Assembler.Relocation(
			label, assembler.output.length-1, 
			Assembler.Relocation.Type.Offset);
			
		assembler.assemblePopManual(Register.RA);
	}
	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleLoadI(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	Register register;
	int value;
	string label;

	if (!assembler.parseRegister(newTokens, register)) return false;
	if (!(assembler.parseNumber(newTokens, value) || assembler.parseLabel(newTokens, label)))
		return false;

	void writeLoadPair()
	{
		ushort high = (value >> 16) & 0xFFFF;
		ushort low =  (value >>  0) & 0xFFFF;

		// Synthesize loadui, loadli
		Opcode loadui;
		loadui.opcode = Opcodes.LoadUi.opcode;
		loadui.encoding = Opcodes.LoadUi.encoding;
		loadui.register1 = register;
		loadui.immediateB = high;

		Opcode loadli;
		loadli.opcode = Opcodes.LoadLi.opcode;
		loadli.encoding = Opcodes.LoadLi.encoding;
		loadli.register1 = register;
		loadli.immediateB = low;

		foreach (_; 0..assembler.repCount)
		{
			assembler.writeOutput(loadui);
			assembler.writeOutput(loadli);

			if (label.length)
			{
				assembler.relocations ~= Assembler.Relocation(
					label, assembler.output.length - 2, 
					Assembler.Relocation.Type.SplitAbsolute);
			}
		}
	}

	// If we're dealing with a value, and it can be packed into 7 bits
	auto absValue = abs(value);
	enum Mask0 = 0b0000_0000_0111_1111;
	if (label.empty && (absValue & Mask0) == absValue)
	{
		Opcode add;
		add.opcode = Opcodes.AddD.opcode;
		add.encoding = Opcodes.AddD.encoding;
		add.operandSize = OperandSize.Byte4;
		add.register1 = register;
		add.register2 = Register.Z;

		enum Mask1 = Mask0 << 1;
		enum Mask2 = Mask0 << 2;
		auto sign = value >= 0 ? 1 : -1;
		// If the value can be packed into 7 bits, multiplied by 1
		if ((absValue & Mask0) == absValue)
		{
			add.immediateD = ((absValue & Mask0) >> 0) * sign;
			add.variant = Variant.Identity;

			foreach (_; 0..assembler.repCount)
				assembler.writeOutput(add);
		}
		// If the value can be packed into 7 bits, multiplied by 2
		else if ((absValue & Mask1) == absValue)
		{
			add.immediateD = ((absValue & Mask1) >> 1) * sign;
			add.variant = Variant.ShiftLeft1;

			foreach (_; 0..assembler.repCount)
				assembler.writeOutput(add);
		}
		// If the value can be packed into 7 bits, multiplied by 4
		else if ((absValue & Mask2) == absValue)
		{
			add.immediateD = ((absValue & Mask2) >> 2) * sign;
			add.variant = Variant.ShiftLeft2;

			foreach (_; 0..assembler.repCount)
				assembler.writeOutput(add);
		}
		// Otherwise, give up and write a load pair
		else
		{
			writeLoadPair();
		}
	}
	else
	{
		// Can't be packed into an add opcode; write a load pair
		writeLoadPair();
	}

	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleDw(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	int value;
	if (!assembler.parseNumber(newTokens, value)) return false;

	foreach (i; 0..assembler.repCount)
		assembler.writeOutput(value);

	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleRep(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	int repCount;
	if (!assembler.parseNumber(newTokens, repCount)) return false;
	assembler.repCount = repCount;
	assembler.tokens = newTokens;

	return true;
}

bool assembleJr(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	Register register;
	if (!assembler.parseRegister(newTokens, register)) return false;

	// Synthesize add
	Opcode add;
	add.opcode = Opcodes.AddA.opcode;
	add.encoding = Opcodes.AddA.encoding;
	add.operandSize = OperandSize.Byte4;
	add.register1 = Register.IP;
	add.register2 = register;
	add.register3 = Register.Z;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(add);

	assembler.finishAssemble(newTokens);

	return true;
}

bool assembleMove(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	OperandSize operandSize;
	Register dst, src;
	if (!assembler.parseSizePrefix(newTokens, operandSize)) return false;
	if (!assembler.parseRegister(newTokens, dst)) return false;
	if (!assembler.parseRegister(newTokens, src)) return false;

	// Synthesize add
	Opcode add;
	add.opcode = Opcodes.AddA.opcode;
	add.encoding = Opcodes.AddA.encoding;
	add.operandSize = operandSize;
	add.register1 = dst;
	add.register2 = src;
	add.register3 = Register.Z;

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(add);

	assembler.finishAssemble(newTokens);

	return true;
}