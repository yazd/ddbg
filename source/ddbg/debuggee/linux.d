module ddbg.debuggee.linux;

import ddbg.common;
import ddbg.concurrency;
import ddbg.debuggee;
import ddbg.sys.ptrace;

import std.exception;
import std.typecons;

import core.thread;

debug import std.stdio;

/// linux debuggee implementation
final class LinuxDebuggee : WhiteHole!Debuggee
{
	private Breakpoint[address_t] breakpoints;
	private Thread m_thread;
	private shared bool m_exited;
	private MessageBox m_controller;
	private MessageBox m_debuggee;

	private void messageLoop()
	{
		import core.sys.posix.stdlib;

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
					m_debuggee.send(Started());
					firstStop = false;
				}
				else
					m_debuggee.send(Stopped(signal));

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

							m_debuggee.send(HitBreakpoint(*bp));
						}
					}
				}
			}

			if (WIFSIGNALED(status))
				m_debuggee.send(Signalled(WTERMSIG(status)));

			if (WIFEXITED(status))
			{
				m_exited = true;
				m_debuggee.send(Exited());
				break;
			}

			bool shouldContinue = false;
			while (!shouldContinue)
			{
				m_debuggee.receive(
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
						m_debuggee.send(BreakpointResponse(bp));
					},
					(RegistersRequest req)
					{
						Registers registers = getRegisters(child);
						m_debuggee.send(RegistersResponse(registers));
					},
					(PeekRequest req)
					{
						PeekResponse response;
						response.word = ptrace(__ptrace_request.PTRACE_PEEKTEXT, child, cast(void*) req.address, null);
						m_debuggee.send(response);
					}
				);
			}
		}
	}

	private void forkSpawn(immutable(char[]) binary, immutable(char[][]) args, immutable(char[][]) env)
	{
		import core.sys.posix.unistd;
		import core.sys.posix.stdlib : exit;

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
		m_thread = new Thread(() {
			forkSpawn(binary, args, env);
		});
		m_thread.isDaemon = true;
		m_thread.start();

		Link link = new Link();
		m_controller = link.parent;
		m_debuggee = link.child;
	}

	override void continue_()
	{
		m_controller.send(Continue());
	}

	override void stepInstruction()
	{
		m_controller.send(SingleStep());
	}

	override Registers registers()
	{
		m_controller.send(RegistersRequest());
		auto response = m_controller.receiveOnly!RegistersResponse();
		return response.registers;
	}

	override Word peek(address_t address)
	{
		m_controller.send(PeekRequest(address));
		auto response = m_controller.receiveOnly!PeekResponse();
		return response.word;
	}

	override void resume(Breakpoint breakpoint)
	{
		stepInstruction();
		m_controller.receiveOnly!Stopped();
		m_controller.send(BreakpointRequest(breakpoint.address));
		m_controller.receiveOnly!BreakpointResponse();
		auto bp = breakpoint.address in breakpoints;
		bp.applied = true;
		continue_();
	}

	override Breakpoint addBreakpoint(address_t address)
	{
		if (auto bp = address in breakpoints) return *bp;
		m_controller.send(BreakpointRequest(address));
		auto response = m_controller.receiveOnly!BreakpointResponse();
		breakpoints[response.breakpoint.address] = response.breakpoint;
		return response.breakpoint;
	}

	override @property bool exited()
	{
		return m_exited;
	}

	override @property MessageBox control()
	{
		return m_controller;
	}
}
