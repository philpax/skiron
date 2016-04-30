module debugger_graphical.main;

import gtk.Application;

import debugger_backend.backend;

import debugger_graphical.debuggerwindow;

int main(string[] args)
{
	auto application = new Application(null, GApplicationFlags.NON_UNIQUE);
	application.addOnActivate((a) { new DebuggerWindow(application); });
	return application.run(args);
}
