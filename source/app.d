import ddbg.debugee;

import std.concurrency;
import std.stdio;

Debuggee dbg;

void main(string[] args)
{
	dbg = new ElfDebuggee();
	dbg.spawn(args[1], args[1 .. $].idup, []);

	while (!dbg.exited)
	{
		receive(
			(Started msg) => onStart(msg),
			(Stopped msg) => onStop(msg),
			(Signalled msg) => onSignal(msg),
			(Attached msg) => onAttach(msg),
			(Exited msg) => onExit(msg),
			(LinkTerminated msg) => writeln("link terminated"),
			(Variant msg) => writeln("uncaught message (", msg.type(), ")"),
		);
	}

	writeln("done");
}

void onStart(Started)
{
	writeln("started");
}

void onStop(Stopped msg)
{
	//writeln("stopped due to signal ", msg.signal);

	//auto registers = dbg.getRegisters();
	//{ // print registers
	//	auto fields = __traits(allMembers, typeof(registers));
	//	auto values = registers.tupleof;

	//	foreach (index, value; values)
	//	{
	//		writef("%-8s 0x%-12x %s\n", fields[index], value, value);
	//	}
	//	writeln();
	//	//writefln("%-8s 0x%-12x", "rip", registers.rip);
	//}

	dbg.stepInstruction();
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
