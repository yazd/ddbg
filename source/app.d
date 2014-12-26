import ddbg.debugee;

import std.concurrency;
import std.stdio;

Debuggee dbg;

void main()
{
	dbg = new ElfDebuggee();
	dbg.spawn("/bin/ls", ["/tmp"], []);

	while (!dbg.exited)
	{
		receive(
			(Started msg) => onStart(),
			(Stopped msg) => onStop(),
			(Signalled msg) => onSignal(),
			(Attached msg) => onAttach(),
			(Exited msg) => onExit(),
			(Variant v) => writeln("uncaught message"),
		);
	}

	writeln("done");
}

void onStart()
{
	writeln("started");
}

void onStop()
{
	writeln("stopped");
//	dbg.continue_();
}

void onSignal()
{
	writeln("signalled");
}

void onAttach()
{
	writeln("attached");
}

void onExit()
{
	writeln("exited");
}
