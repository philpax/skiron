module common.util.path;

string getSkironExecutablePath(string executable)
{
	import std.file : thisExePath;
	import std.path : dirName, buildPath;
	return thisExePath.dirName.buildPath(executable);
}