module ddbg.debugee;

public import ddbg.debugee.elf;

import ddbg.breakpoint;
import ddbg.register;
import ddbg.common;

/// Messages
struct Started {}
/// ditto
struct Stopped { int signal; }
/// ditto
struct Signalled { int signal; }
/// ditto
struct Attached {}
/// ditto
struct Exited {}
/// ditto
struct Continue {}

/// Debuggee interface
interface Debuggee
{
	/// returns a new Debuggee instance by spawning a new process
	void spawn(immutable(char[]) binary, immutable(char[][]) args, immutable(char[][]) env);

	/// returns a new Debuggee instance by attaching to a running process
	void attach(pid_t pid);

	/// adds a new breakpoint
	Breakpoint addBreakpoint(address_t address);

	/// remove breakpoint
	void removeBreakpoint(Breakpoint breakpoint);

	/// pauses the debuggee
	void pause();

	/// continues the debuggee
	void continue_();

	/// step by instruction
	void stepInstruction();

	/// returns the current value of registers
	Register[] getRegisters();

	/// has the debuggee exited
	@property bool exited();
}
