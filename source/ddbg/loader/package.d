module ddbg.loader;

public import ddbg.loader.elf;

import ddbg.common;
import std.typecons;

struct SourceLocation
{
	string file;
	ulong line;
}

struct Function
{
	string name;
	address_t address;

	import std.bitmanip;
	mixin(bitfields!(
		bool, "isWeak", 1,
		bool, "isGlobal", 1,
		bool, "isLocal", 1,
		bool, "", 5,
	));
}

interface Loader
{
	Function[] getFunctions();
	address_t[] addressFromSrcLocation(SourceLocation);
	Nullable!SourceLocation srcLocationFromAddress(address_t);
}
