import gtk.Application;

// Windows
import gtk.ApplicationWindow, gtk.Window;
// Menu
import gtk.MenuBar, gtk.MenuItem;
// Input
import gtk.Entry, gtk.Button;
// Display
import gtk.Label, gtk.TextView;
// Layout
import gtk.VBox, gtk.HBox;

import std.socket;

class ConnectWindow : Window
{
	Entry ipAddressEntry;
	Entry portEntry;

	Debugger debugger;

	this(Debugger debugger)
	{
		super("Connect to Simulator");
		
		this.debugger = debugger;
		this.setBorderWidth(10);

		this.ipAddressEntry = new Entry("127.0.0.1");
		this.portEntry = new Entry("1234");

		auto vbox = new VBox(false, 2);

		auto ipBox = new HBox(false, 2);
		ipBox.packStart(new Label("IP address"), false, false, 5);
		ipBox.packEnd(this.ipAddressEntry, false, false, 5);
		vbox.packStart(ipBox, false, false, 5);

		auto portBox = new HBox(false, 2);
		portBox.packStart(new Label("Port"), false, false, 5);
		portBox.packEnd(this.portEntry, false, false, 5);
		vbox.packStart(portBox, false, false, 5);

		vbox.packEnd(new Button("Connect", &this.onConnectClick), true, true, 5);
		this.add(vbox);

		this.setVisible(false);
	}

	void onConnectClick(Button)
	{
		this.debugger.start(this.ipAddressEntry.getText(), this.portEntry.getText());
		this.setVisible(false);
	}
}

class Debugger : ApplicationWindow
{
	MenuBar menu;
	ConnectWindow connectWindow;
	Socket connection;
	TextView logView;

	this(Application application)
	{
		super(application);
		this.setTitle("Skiron Debugger");
		this.setDefaultSize(640, 480);

		auto vbox = new VBox(false, 0);

		this.menu = new MenuBar();
		this.menu.append(new MenuItem(&this.onConnectClick, "Connect"));
		vbox.packStart(this.menu, false, false, 0);

		this.logView = new TextView();
		this.logView.setEditable(false);
		vbox.packEnd(this.logView, true, true, 5);

		this.add(vbox);

		this.connectWindow = new ConnectWindow(this);

		this.showAll();
	}

	void onConnectClick(MenuItem)
	{
		this.connectWindow.showAll();
	}

	void start(string ipAddress, string port)
	{
		this.log("Connecting to %s:%s", ipAddress, port);
		auto addressInfo = getAddressInfo(ipAddress, port)[0];
		this.connection = new Socket(addressInfo);
		this.connection.connect(addressInfo.address);
		this.log("Connection status: %s", this.connection.isAlive);
		
	}

	void log(Args...)(string text, auto ref Args args)
	{
		import std.string;

		this.logView.appendText((text ~ "\n").format(args));
	}
}

int main(string[] args)
{
	auto application = new Application(null, GApplicationFlags.NON_UNIQUE);
	application.addOnActivate((a) { new Debugger(application); });
	return application.run(args);
}
