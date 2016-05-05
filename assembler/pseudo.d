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
	auto add = makeOpcode!(Opcodes.AddD);
	add.operandSize = OperandSize.Byte4;
	add.register1 = Register.SP;
	add.register2 = Register.SP;
	add.immediate = -4;

	auto store = makeOpcode!(Opcodes.Store);
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

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.assemblePushManual(register, operandSize);

	return true;
}

void assemblePopManual(ref Assembler assembler, Register register, OperandSize operandSize = OperandSize.Byte4)
{
	// Synthesize load, add
	auto load = makeOpcode!(Opcodes.Load);
	load.operandSize = operandSize;
	load.register1 = register;
	load.register2 = Register.SP;

	auto add = makeOpcode!(Opcodes.AddD);
	add.operandSize = OperandSize.Byte4;
	add.register1 = Register.SP;
	add.register2 = Register.SP;
	add.immediate = 4;

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

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.assemblePopManual(register, operandSize);

	return true;
}

bool assembleCallSv(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	auto call = makeOpcode!(Opcodes.Call);

	string label;
	if (!assembler.parseLabel(newTokens, label)) return false;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
	{
		assembler.assemblePushManual(Register.RA);
			
		assembler.writeOutput(call);
		assembler.relocations ~= Assembler.Relocation(
			label, assembler.output.length-1, 
			Assembler.Relocation.Type.Offset);
			
		assembler.assemblePopManual(Register.RA);
	}

	return true;
}

bool assembleLoadI(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	import std.algorithm : filter;

	auto newTokens = assembler.tokens;

	Register register;
	int value;
	string label;

	if (!assembler.parseRegister(newTokens, register)) 
		return false;

	if (!assembler.parseNumber(newTokens, value) && !assembler.parseLabel(newTokens, label))
		return false;

	void writeLoadPair()
	{
		ushort high = (value >> 16) & 0xFFFF;
		ushort low =  (value >>  0) & 0xFFFF;

		// Synthesize loadui, loadli
		auto loadui = makeOpcode!(Opcodes.LoadUi);
		loadui.register1 = register;
		loadui.immediate = high;

		auto loadli = makeOpcode!(Opcodes.LoadLi);
		loadli.register1 = register;
		loadli.immediate = low;

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

	// If we're dealing with a value, and it can be packed
	auto absValue = abs(value);

	// Remove 1 from BitCount to account for the sign mask
	enum BitCount = Opcode.EncodingDocsD.fields
										.filter!(a => a.name == "immediate")
										.front.size - 1;

	// Add 2 to account for the shifting possible
	enum MaskAll = ~(~0 << (BitCount + 2));
	if (label.empty && (absValue & MaskAll) == absValue)
	{
		auto add = makeOpcode!(Opcodes.AddD);
		add.operandSize = OperandSize.Byte4;
		add.register1 = register;
		add.register2 = Register.Z;

		auto sign = value >= 0 ? 1 : -1;
		
		enum Mask0 = ~(~0 << BitCount);
		enum Mask1 = Mask0 << 1;
		enum Mask2 = Mask0 << 2;
		// If the value can be packed into n bits, multiplied by 1
		if ((absValue & Mask0) == absValue)
		{
			add.immediate = ((absValue & Mask0) >> 0) * sign;
			add.variant = Variant.Identity;

			foreach (_; 0..assembler.repCount)
				assembler.writeOutput(add);
		}
		// If the value can be packed into n bits, multiplied by 2
		else if ((absValue & Mask1) == absValue)
		{
			add.immediate = ((absValue & Mask1) >> 1) * sign;
			add.variant = Variant.ShiftLeft1;

			foreach (_; 0..assembler.repCount)
				assembler.writeOutput(add);
		}
		// If the value can be packed into n bits, multiplied by 4
		else if ((absValue & Mask2) == absValue)
		{
			add.immediate = ((absValue & Mask2) >> 2) * sign;
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

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (i; 0..assembler.repCount)
		assembler.writeOutput(value);

	return true;
}

bool assembleRep(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	return assembler.parseNumber(assembler.tokens, assembler.repCount);
}

bool assembleJr(ref Assembler assembler, const(OpcodeDescriptor)* descriptor)
{
	auto newTokens = assembler.tokens;

	Register register;
	if (!assembler.parseRegister(newTokens, register)) return false;

	// Synthesize add
	auto add = makeOpcode!(Opcodes.AddA);
	add.operandSize = OperandSize.Byte4;
	add.register1 = Register.IP;
	add.register2 = register;
	add.register3 = Register.Z;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(add);

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
	auto add = makeOpcode!(Opcodes.AddA);
	add.operandSize = operandSize;
	add.register1 = dst;
	add.register2 = src;
	add.register3 = Register.Z;

	scope (exit)
		assembler.finishAssemble(newTokens);

	foreach (_; 0..assembler.repCount)
		assembler.writeOutput(add);

	return true;
}