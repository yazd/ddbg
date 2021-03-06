module ddbg.sys.registers;

import core.stdc.config;

extern(C):

struct user_regs_struct_32
{
  c_ulong ebx;
  c_ulong ecx;
  c_ulong edx;
  c_ulong esi;
  c_ulong edi;
  c_ulong ebp;
  c_ulong eax;
  c_ulong xds;
  c_ulong xes;
  c_ulong xfs;
  c_ulong xgs;
  c_ulong orig_eax;
  c_ulong eip;
  c_ulong xcs;
  c_ulong eflags;
  c_ulong esp;
  c_ulong xss;
}

struct user_regs_struct_64
{
  c_ulong r15;
  c_ulong r14;
  c_ulong r13;
  c_ulong r12;
  c_ulong rbp;
  c_ulong rbx;
  c_ulong r11;
  c_ulong r10;
  c_ulong r9;
  c_ulong r8;
  c_ulong rax;
  c_ulong rcx;
  c_ulong rdx;
  c_ulong rsi;
  c_ulong rdi;
  c_ulong orig_rax;
  c_ulong rip;
  c_ulong cs;
  c_ulong eflags;
  c_ulong rsp;
  c_ulong ss;
  c_ulong fs_base;
  c_ulong gs_base;
  c_ulong ds;
  c_ulong es;
  c_ulong fs;
  c_ulong gs;
}

version(X86)
{
	alias user_regs_struct = user_regs_struct_32;
}
else version(X86_64)
{
	alias user_regs_struct = user_regs_struct_64;
}
else
{
  static assert(0, "unsupported architecture");
}