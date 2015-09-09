solution "skiron"
	configurations { "release", "debug" }

	project "emulator"
		kind "ConsoleApp"
		language "D"
		targetdir "bin"
		debugdir "bin"

		files { "common/**.d", "emulator/**.d" }