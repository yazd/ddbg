module ddbg.debugee.elf;

import ddbg.debugee;
import ddbg.ptrace;

import std.string;
import std.exception;
import std.algorithm;
import std.range;
import std.concurrency;
import std.typecons;

import core.sys.posix.stdlib;
import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;
import core.stdc.config;

/// elf debugee implementation
class ElfDebuggee : WhiteHole!Debuggee
{
	private Tid m_debuggee;
	private shared bool m_exited;

	private void messageLoop() shared
	{
		int status;

		do
		{
			int child = wait(&status);

			if (WIFSTOPPED(status))
			{
				ownerTid().send(Stopped(WSTOPSIG(status)));

				receive(
					(Continue req) { ptrace(__ptrace_request.PTRACE_CONT, child, null, null); },
				);
			}

			if (WIFSIGNALED(status))
			{
				ownerTid().send(Signalled(WTERMSIG(status)));
			}
		}
		while (!WIFEXITED(status));
		ownerTid().send(Exited());
		m_exited = true;
	}

	private void forkSpawn(immutable(char[]) binary, immutable(char[][]) args, immutable(char[][]) env) shared
	{
		auto pid = fork();
		enforce(pid >= 0, "fork failed");

		if (pid == 0)
		{
			// child
			enforce(ptrace(__ptrace_request.PTRACE_TRACEME, 0, null, null) == 0, "ptrace failed");
			execve(binary.toStringz(), chain(only(binary), args).map!toStringz.chain(only(null)).array().ptr, env.map!toStringz.chain(only(null)).array().ptr);
			exit(0);
		}
		else if (pid > 0)
		{
			// parent
			messageLoop();
		}
	}

	///
	override void spawn(immutable(char[]) binary, immutable(char[][]) args, immutable(char[][]) env)
	{
		m_debuggee = std.concurrency.spawnLinked(&forkSpawn, binary, args, env);
	}

	override void continue_()
	{
		m_debuggee.send(Continue());
	}

	override @property bool exited()
	{
		return m_exited;
	}
}
