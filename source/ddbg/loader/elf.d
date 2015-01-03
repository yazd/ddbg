module ddbg.loader.elf;

import ddbg.loader;
import ddbg.common;

import elf;

import std.range,
			 std.typecons;

final class ElfBinary : WhiteHole!Loader
{
	private ELF m_elf;

	this(string filepath)
	{
		m_elf = ELF.fromFile(filepath);
	}

	override
	Function[] getFunctions()
	{
		Function[] result;
		foreach (sectionName; only(".symtab", ".dynsym"))
		{
			Nullable!ELFSection section = m_elf.getSection(sectionName);
			if (section.isNull()) continue;

			foreach (symbol; SymbolTable(section.get()).symbols()) if (symbol.type == SymbolType.func)
			{
				auto f = Function(symbol.name, symbol.value);
				f.isWeak = (symbol.binding & SymbolBinding.weak) != 0;
				f.isGlobal = (symbol.binding & SymbolBinding.global) != 0;
				f.isLocal = (symbol.binding & SymbolBinding.local) != 0;
				result ~= f;
			}
		}

		return result;
	}

	override
	address_t[] addressFromSrcLocation(SourceLocation loc)
	{
		address_t[] result;
		Nullable!ELFSection section = m_elf.getSection(".debug_line");
		if (section.isNull()) return result;

		auto dl = DebugLine(section);
		foreach (program; dl.programs) {
			foreach (addrInfo; program.addressInfo) if (program.fileFromIndex(addrInfo.fileIndex) == loc.file) // fix file comparison
			{
				if (addrInfo.line == loc.line) result ~= addrInfo.address;
			}
		}

		return result;
	}

	override
	Nullable!SourceLocation srcLocationFromAddress(address_t addr)
	{
		Nullable!ELFSection section = m_elf.getSection(".debug_line");
		if (section.isNull()) return Nullable!SourceLocation();

		SourceLocation lastLoc;
		address_t lastAddr = 0;

		auto dl = DebugLine(section);
		foreach (program; dl.programs) {
			foreach (addrInfo; program.addressInfo)
			{
				if (addrInfo.address > addr && addr >= lastAddr) return Nullable!SourceLocation(lastLoc);

				lastLoc = SourceLocation(program.fileFromIndex(addrInfo.fileIndex), addrInfo.line);
				lastAddr = addrInfo.address;
			}
		}

		return Nullable!SourceLocation();
	}
}
