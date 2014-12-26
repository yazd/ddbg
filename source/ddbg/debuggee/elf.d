module ddbg.debuggee.elf;

import ddbg.common;
import ddbg.debuggee;
import ddbg.sys.ptrace;

import std.exception;
import std.concurrency;
import std.typecons;

import core.sys.posix.stdlib;
import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;
import core.stdc.config;

/// elf debuggee implementation
class ElfDebuggee : WhiteHole!Debuggee
{
	private Tid m_debuggee;
	private shared bool m_exited;

	private void messageLoop() shared
	{
		while (true)
		{
			int status;
			int child = wait(&status);

			if (WIFSTOPPED(status))
				ownerTid().send(Stopped(WSTOPSIG(status)));

			if (WIFSIGNALED(status))
				ownerTid().send(Signalled(WTERMSIG(status)));

			if (WIFEXITED(status))
			{
				m_exited = true;
				ownerTid().send(Exited());
				break;
			}

			bool shouldContinue = false;
			while (!shouldContinue)
			{
				receive(
					(Continue req)
					{
						ptrace(__ptrace_request.PTRACE_CONT, child, null, null);
						shouldContinue = true;
					},
					(SingleStep req)
					{
						ptrace(__ptrace_request.PTRACE_SINGLESTEP, child, null, null);
						shouldContinue = true;
					},
					(RegistersRequest req)
					{
						RegistersResponse response;
						ptrace(__ptrace_request.PTRACE_GETREGS, child, null, &response.registers);
						ownerTid().send(response);
					},
					(PeekRequest req)
					{
						PeekResponse response;
						response.word = ptrace(__ptrace_request.PTRACE_PEEKTEXT, child, cast(void*) req.address, null);
						ownerTid().send(response);
					}
				);
			}
		}
	}

	private void forkSpawn(immutable(char[]) binary, immutable(char[][]) args, immutable(char[][]) env) shared
	{
		auto pid = fork();
		enforce(pid >= 0, "fork failed");

		if (pid == 0)
		{
			// child
			import std.algorithm : map;
			import std.range : array, chain, only;
			import std.string : toStringz;

			enforce(ptrace(__ptrace_request.PTRACE_TRACEME, 0, null, null) == 0, "ptrace failed");
			execve(binary.toStringz(), args.map!toStringz.chain(only(null)).array().ptr, env.map!toStringz.chain(only(null)).array().ptr);
			exit(0);
		}
		else if (pid > 0)
		{
			// parent
			messageLoop();
		}
	}

	override void spawn(immutable(char[]) binary, immutable(char[][]) args, immutable(char[][]) env)
	{
		m_debuggee = spawnLinked(&forkSpawn, binary, args, env);
	}

	override void continue_()
	{
		m_debuggee.send(Continue());
	}

	override void stepInstruction()
	{
		m_debuggee.send(SingleStep());
	}

	override Registers registers()
	{
		m_debuggee.send(RegistersRequest());
		auto response = receiveOnly!RegistersResponse();
		return response.registers;
	}

	override Word peek(address_t address)
	{
		m_debuggee.send(PeekRequest(address));
		auto response = receiveOnly!PeekResponse();
		return response.word;
	}

	override @property bool exited()
	{
		return m_exited;
	}
}
