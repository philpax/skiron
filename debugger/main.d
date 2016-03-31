import gio.Application : GioApplication = Application;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Label;

class Debugger : ApplicationWindow
{
	this(Application application)
	{
		super(application);
		setTitle("Skiron Debugger");
		setBorderWidth(10);

		showAll();
	}
}

int main(string[] args)
{
	auto application = new Application(null, GApplicationFlags.NON_UNIQUE);
	application.addOnActivate(delegate void(GioApplication app) { new Debugger(application); });
	return application.run(args);
}
