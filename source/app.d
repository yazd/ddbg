import ddbg.debuggee;

import std.concurrency;
import std.stdio;

Debuggee dbg;

void main(string[] args)
{
	dbg = new LinuxDebuggee();
	dbg.spawn(args[1], args[1 .. $].idup, []);

	while (!dbg.exited)
	{
		receive(
			(Started msg) => onStart(msg),
			(Stopped msg) => onStop(msg),
			(Signalled msg) => onSignal(msg),
			(Attached msg) => onAttach(msg),
			(Exited msg) => onExit(msg),
			(HitBreakpoint msg) => onHitBreakpoint(msg),
			(LinkTerminated msg) => writeln("link terminated"),
			(Variant msg) => writeln("uncaught message (", msg.type(), ")"),
		);
	}

	writeln("done");
}

void onStart(Started)
{
	writeln("started");
	dbg.addBreakpoint(0x40052c);
	dbg.continue_();
}

void onStop(Stopped msg)
{
	writeln("stopped");

	//
	//{ // print registers
	//	auto fields = __traits(allMembers, typeof(registers));
	//	auto values = registers.tupleof;

	//	foreach (index, value; values)
	//	{
	//		writef("%-8s 0x%-12x %s\n", fields[index], value, value);
	//	}
	//	writeln();
	//writefln("%-8s 0x%-12x", "rip", cast(void*)registers.rip);
	//}
}

void onSignal(Signalled msg)
{
	writeln("signalled ", msg.signal);
}

void onAttach(Attached)
{
	writeln("attached");
}

void onExit(Exited)
{
	writeln("exited");
}

void onHitBreakpoint(HitBreakpoint msg)
{
	writefln("hit breakpoint 0x%x", msg.breakpoint.address);
	//auto registers = dbg.registers();
	//writefln("%-8s 0x%-12x", "rip", cast(void*)registers.rip);
	dbg.resume(msg.breakpoint);
}
