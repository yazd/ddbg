module ddbg.breakpoint;

import ddbg.common;

struct Breakpoint
{
	address_t address;
	package ubyte origValue;
	package bool applied;
}