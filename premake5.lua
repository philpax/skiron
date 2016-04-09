solution "skiron"
	configurations { "release", "debug", "unittest" }

	project "emulator"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		files { "common/**.d", "emulator/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "assembler"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		files { "common/**.d", "assembler/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "disassembler"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		files { "common/**.d", "disassembler/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "debugger_backend"
		kind "StaticLib"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		files { "common/**.d", "debugger_backend/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "debugger_graphical"
		kind "WindowedApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		includedirs { "vendor/gtkd/src", "debugger_backend/" }
		files { "common/**.d", "debugger_graphical/**.d" }
		links { "vendor/gtkd/gtkd.lib", "debugger_backend" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "docgen"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		files { "common/**.d", "docgen/**.d" }

		filter "action:vs*"
			postbuildcommands "chdir bin && docgen && chdir ../"

		filter "action:not vs*"
			postbuildcommands "{CHDIR} bin && ./docgen"

		filter {}

		filter "configurations:unittest"
			flags { "UnitTest" }