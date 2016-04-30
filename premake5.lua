solution "skiron"
	configurations { "release", "debug", "unittest" }

	group "vendor"
		project "gtkd"
			kind "StaticLib"
			language "D"
			targetdir "bin"
			debugdir "bin"

			files { "vendor/gtkd/src/**.d" }

			filter "configurations:unittest"
				flags { "UnitTest" }

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

		project "arsd"
			kind "StaticLib"
			language "D"
			targetdir "bin"
			debugdir "bin"
			flags { "SymbolsLikeC" }

			files { "vendor/arsd/simpledisplay.d", "vendor/arsd/color.d" }

			filter "configurations:unittest"
				flags { "UnitTest" }

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

	group ""
		project "common"
			kind "StaticLib"
			language "D"
			targetdir "bin"
			debugdir "bin"
			flags { "SymbolsLikeC" }

			files { "common/**.d" }

			filter "configurations:unittest"
				flags { "UnitTest" }

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"	

		project "emulator"
			kind "ConsoleApp"
			language "D"
			targetdir "bin"
			debugdir "bin"
			flags { "SymbolsLikeC" }

			links { "bin/common.lib", "bin/arsd.lib" }
			includedirs { "common/", "vendor/" }
			files { "emulator/**.d" }

			filter "configurations:unittest"
				flags { "UnitTest" }

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

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

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

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

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

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

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

		project "debugger_graphical"
			kind "WindowedApp"
			language "D"
			targetdir "bin"
			debugdir "bin"
			flags { "SymbolsLikeC" }

			includedirs { "vendor/gtkd/src", "common/", "debugger_backend/" }
			files { "debugger_graphical/**.d" }
			links { "bin/gtkd.lib", "bin/debugger_backend.lib", "bin/common.lib" }

			filter "configurations:unittest"
				flags { "UnitTest" }

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

		project "test_runner"
			kind "ConsoleApp"
			language "D"
			targetdir "bin"
			debugdir "bin"
			flags { "SymbolsLikeC" }

			links { "bin/debugger_backend.lib", "bin/common.lib" }
			includedirs { "common/", "debugger_backend/" }
			files { "test_runner/**.d" }

			filter "configurations:unittest"
				flags { "UnitTest" }

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"

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

			filter "configurations:release"
				flags { "NoBoundsCheck" }
				optimize "full"