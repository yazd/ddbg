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
	writeln("stopped due to signal ", msg.signal);
	dbg.continue_();
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
