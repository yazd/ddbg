module ddbg.debuggee;

public import ddbg.debuggee.linux;

public import ddbg.concurrency;
public import ddbg.breakpoint;
public import ddbg.register;
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
/// ditto
struct SingleStep {}
/// ditto
struct RegistersRequest {}
/// ditto
struct RegistersResponse { Registers registers; }
/// ditto
struct PeekRequest { address_t address; }
/// ditto
struct PeekResponse { Word word; }
/// ditto
struct BreakpointRequest { address_t address; }
/// ditto
struct BreakpointResponse { Breakpoint breakpoint; }
/// ditto
struct HitBreakpoint { Breakpoint breakpoint; }

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

	/// resumes from breakpoint
	void resume(Breakpoint bp);

	/// step by instruction
	void stepInstruction();

	/// returns the current value of registers
	Registers registers();

	/// reads a word from address
	Word peek(address_t address);

	/// did the debuggee exit
	@property bool exited();

	/// returns the controller messagebox
	@property MessageBox control();
}
