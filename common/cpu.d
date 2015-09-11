module common.cpu;

enum RegisterCount = 64;
enum Register
{
	// Zero register (always 0)
	Z = 60,
	// Stack base pointer
	BP = 61,
	// Stack top pointer
	SP = 62,
	// Instruction pointer
	IP = 63
}