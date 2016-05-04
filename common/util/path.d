module common.util.path;

string getSkironExecutablePath(string executable)
{
	import std.path : thisExePath, dirName, buildPath;
	return thisExePath.dirName.buildPath(executable);
}