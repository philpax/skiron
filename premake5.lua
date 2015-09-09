solution "skiron"
	configurations { "release", "debug", "unittest" }

	project "emulator"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"

		files { "common/**.d", "emulator/**.d" }

		filter "configurations:unittest"
			flags { "UnitTest" }