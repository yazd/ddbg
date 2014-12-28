module ddbg.register;

import ddbg.common;
import ddbg.sys.registers;

alias Registers = user_regs_struct;

size_t getIP(Registers registers)
{
	version(X86)
	{
		return registers.eip;
	}
	else version(X86_64)
	{
		return registers.rip;
	}
	else
	{
		static assert(0, "unsupported architecture");
	}
}

void setIP(ref Registers registers, size_t ip)
{
	version(X86)
	{
		registers.eip = ip;
	}
	else version(X86_64)
	{
		registers.rip = ip;
	}
	else
	{
		static assert(0, "unsupported architecture");
	}
}
