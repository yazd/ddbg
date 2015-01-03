import ddbg.debuggee;
import ddbg.loader;

import std.stdio;

Debuggee dbg;
Loader ldr;

void main(string[] args)
{
	import std.string, std.algorithm;
	ldr = new ElfBinary(args[1]);

	dbg = new LinuxDebuggee();
	dbg.spawn(args[1], args[1 .. $].idup, []);

	while (!dbg.exited)
	{
		dbg.control.receive(
			(Started msg) => onStart(msg),
			(Stopped msg) => onStop(msg),
			(Signalled msg) => onSignal(msg),
			(Attached msg) => onAttach(msg),
			(Exited msg) => onExit(msg),
			(HitBreakpoint msg) => onHitBreakpoint(msg),
			//(LinkTerminated msg) => writeln("link terminated"),
			//(Variant msg) => writeln("uncaught message (", msg.type(), ")"),
		);
	}

	writeln("done");
}

void onStart(Started)
{
	writeln("started");
	foreach (func; ldr.getFunctions()) if (func.name == "main")
		dbg.addBreakpoint(func.address);

	foreach (addr; ldr.addressFromSrcLocation(SourceLocation("printf.c", 10)))
		dbg.addBreakpoint(addr);

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
