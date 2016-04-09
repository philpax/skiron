solution "skiron"
	configurations { "release", "debug", "unittest" }

	project "common"
		kind "StaticLib"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		files { "common/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }		

	project "emulator"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		links { "bin/common.lib" }
		includedirs { "common/" }
		files { "emulator/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "assembler"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		links { "bin/common.lib" }
		includedirs { "common/" }
		files { "assembler/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "disassembler"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		links { "bin/common.lib" }
		includedirs { "common/" }
		files { "disassembler/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "debugger_backend"
		kind "StaticLib"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		links { "bin/common.lib" }
		includedirs { "common/" }
		files { "debugger_backend/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "debugger_graphical"
		kind "WindowedApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		includedirs { "vendor/gtkd/src", "common/", "debugger_backend/" }
		files { "debugger_graphical/**.d" }
		links { "vendor/gtkd/gtkd.lib", "bin/debugger_backend.lib", "bin/common.lib" }

		filter "configurations:unittest"
			flags { "UnitTest" }

	project "docgen"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"
		flags { "SymbolsLikeC" }

		links { "bin/common.lib" }
		includedirs { "common/" }
		files { "docgen/**.d" }

		filter "action:vs*"
			postbuildcommands "chdir bin && docgen && chdir ../"

		filter "action:not vs*"
			postbuildcommands "{CHDIR} bin && ./docgen"

		filter {}

		filter "configurations:unittest"
			flags { "UnitTest" }