module ddbg.concurrency;

import std.container;
import std.variant;
import std.traits;
import core.sync.mutex;
import core.sync.semaphore;

template hasLocalAliasing(T...)
{
    static if( !T.length )
        enum hasLocalAliasing = false;
    else
        enum hasLocalAliasing = (std.traits.hasLocalAliasing!(T[0]) && !is(T[0] == MessageBox)) ||
                                ddbg.concurrency.hasLocalAliasing!(T[1 .. $]);
}

class Link
{
	private MessageBox[2] m_messageBoxes;

	this()
	{
		m_messageBoxes[0] = new MessageBox();
		m_messageBoxes[1] = new MessageBox();

		m_messageBoxes[0].linkMessageBox(m_messageBoxes[1]);
		m_messageBoxes[1].linkMessageBox(m_messageBoxes[0]);
	}

	@property MessageBox[2] messageBoxes()
	{
		return m_messageBoxes;
	}

	@property MessageBox parent()
	{
		return m_messageBoxes[0];
	}

	@property MessageBox child()
	{
		return m_messageBoxes[1];
	}
}

class MessageBox
{
	private DList!Variant m_messages;
	private MessageBox m_linkedMessageBox;
	private Semaphore m_semaphore;
	private Mutex m_mutex;

	private this()
	{
		m_semaphore = new Semaphore();
		m_mutex = new Mutex();
	}

	private void linkMessageBox(MessageBox linkedMessageBox)
	{
		m_linkedMessageBox = linkedMessageBox;
	}

	void send(MessageType)(MessageType message)
	{
		static assert(!hasLocalAliasing!MessageType, "Aliases to mutable thread-local data not allowed.");
		m_linkedMessageBox.m_mutex.lock();
		m_linkedMessageBox.m_messages.insertBack(Variant(message));
		m_linkedMessageBox.m_mutex.unlock();
		m_linkedMessageBox.m_semaphore.notify();
	}

	MessageType receiveOnly(MessageType)()
	{
		m_semaphore.wait();
		m_mutex.lock();
		Variant message = m_messages.front;
		m_messages.removeFront();
		m_mutex.unlock();
		return message.get!MessageType();
	}

	void receive(Handler...)(Handler handlers)
	{
		m_semaphore.wait();
		m_mutex.lock();
		Variant message = m_messages.front;
		m_messages.removeFront();
		m_mutex.unlock();

		foreach (handler; handlers)
		{
			alias Parameters = ParameterTypeTuple!handler;
			static assert(Parameters.length == 1, "each handler must have one parameter only");
			if (message.type is typeid(Parameters[0]))
			{
				handler(message.get!(Parameters[0]));
				return;
			}
		}

		throw new Exception("unknown message");
	}

	bool receiveTimeout(Handler...)(Duration timeout, Handler handlers)
	{
		if (!m_semaphore.wait(timeout)) return false;
		m_mutex.lock();
		Variant message = m_messages.front;
		m_messages.removeFront();
		m_mutex.unlock();

		foreach (handler; handlers)
		{
			alias Parameters = ParameterTypeTuple!handler;
			static assert(Parameters.length == 1, "each handler must have one parameter only");
			if (message.type is typeid(Parameters[0]))
			{
				handler(message.get!(Parameters[0]));
				return true;
			}
		}
	}
}
