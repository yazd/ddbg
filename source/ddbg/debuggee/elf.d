module ddbg.debuggee.elf;

import ddbg.common;
import ddbg.debuggee;
import ddbg.sys.ptrace;

debug import std.stdio;
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
	private Breakpoint[address_t] breakpoints;
	private Tid m_debuggee;
	private shared bool m_exited;

	private void messageLoop() shared
	{
		static Registers getRegisters(ddbg.common.pid_t child)
		{
			Registers registers;
			ptrace(__ptrace_request.PTRACE_GETREGS, child, null, &registers);
			return registers;
		}

		bool firstStop = true;

		while (true)
		{
			int status;
			int child = wait(&status);

			if (WIFSTOPPED(status))
			{
				int signal = WSTOPSIG(status);

				if (firstStop)
				{
					ownerTid().send(Started());
					firstStop = false;
				}
				else
					ownerTid().send(Stopped(signal));

				if (signal == 5)
				{
					auto registers = getRegisters(child);
					address_t ip = registers.getIP();

					// if stopped due to a breakpoint, fix
					if (auto bp = (ip - 1) in breakpoints)
					{
						if (bp.applied)
						{
							// restore original value
							Word currentValue = ptrace(__ptrace_request.PTRACE_PEEKTEXT, child, cast(void*) bp.address, null);
							Word newValue = (currentValue & ~0xFF) | bp.origValue;
							ptrace(__ptrace_request.PTRACE_POKETEXT, child, cast(void*) bp.address, cast(void*) newValue);
							bp.applied = false;

							// fix instruction pointer
							registers.setIP(ip - 1);
							ptrace(__ptrace_request.PTRACE_SETREGS, child, null, &registers);

							ownerTid().send(HitBreakpoint(*bp));
						}
					}
				}
			}

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
					(BreakpointRequest req)
					{
						Breakpoint bp;

						Word word = ptrace(__ptrace_request.PTRACE_PEEKTEXT, child, cast(void*) req.address, null);
						bp.address = req.address;
						bp.origValue = word & 0xFF;

						Word newValue = (word & ~0xFF) | 0xCC;
						ptrace(__ptrace_request.PTRACE_POKETEXT, child, cast(void*) req.address, cast(void*) newValue);
						bp.applied = true;
						ownerTid().send(BreakpointResponse(bp));
					},
					(RegistersRequest req)
					{
						Registers registers = getRegisters(child);
						ownerTid().send(RegistersResponse(registers));
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

	override void resume(Breakpoint breakpoint)
	{
		stepInstruction();
		receiveOnly!Stopped();
		m_debuggee.send(BreakpointRequest(breakpoint.address));
		receiveOnly!BreakpointResponse();
		auto bp = breakpoint.address in breakpoints;
		bp.applied = true;
		continue_();
	}

	override Breakpoint addBreakpoint(address_t address)
	{
		if (auto bp = address in breakpoints) return *bp;
		m_debuggee.send(BreakpointRequest(address));
		auto response = receiveOnly!BreakpointResponse();
		breakpoints[response.breakpoint.address] = response.breakpoint;
		return response.breakpoint;
	}

	override @property bool exited()
	{
		return m_exited;
	}
}
