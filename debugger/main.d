import gtk.Application;

// Windows
import gtk.ApplicationWindow, gtk.Window;
// Menu
import gtk.MenuBar, gtk.MenuItem;
// Input
import gtk.Entry, gtk.Button;
// Display
import gtk.Label, gtk.TextView, gtk.ListBox, gtk.ListBoxRow;
// Layout
import gtk.VBox, gtk.HBox, gtk.Notebook, gtk.Table, gtk.ScrolledWindow, gtk.Frame;
// Other
import gtk.Widget, gdk.FrameClock, gdk.Event;
// TreeView
import gtk.ListStore, gtk.TreeView, gtk.TreeViewColumn, gtk.CellRendererText, gtk.TreeIter;

import std.conv, std.string, std.range, std.algorithm;

import common.debugging;
import common.socket;
import common.util;
import common.cpu;
import common.opcode;

struct Core
{
	uint index;
	Widget widget;
	ListStore listStore;
	TreeIter iter;

	// State
	bool running;
	RegisterType[RegisterExtendedCount] registers;

	void updateUI()
	{
		foreach (index, value; this.registers)
			this.listStore.setValue(iter, index, value);
	}
}

class ConnectWindow : Window
{
	Entry ipAddressEntry;
	Entry portEntry;
	Button button;

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

		this.button = new Button("Connect", &this.onConnectClick);
		vbox.packEnd(this.button, true, true, 5);
		this.add(vbox);

		this.setVisible(false);
	}

	void onConnectClick(Button)
	{
		this.debugger.start(this.ipAddressEntry.getText(), this.portEntry.getText());
		this.setVisible(false);
	}

	void makeVisible()
	{
		Window.showAll();
		this.grabFocus();
	}
}

class Debugger : ApplicationWindow
{
	MenuBar menu;
	ConnectWindow connectWindow;
	NonBlockingSocket connection;
	ListBox logView;

	MenuItem connectItem;
	MenuItem disconnectItem;

	Notebook notebook;

	Widget[] coreWidgets;
	Core[] cores;

	this(Application application)
	{
		super(application);
		this.setTitle("Skiron Debugger");
		this.setDefaultSize(640, 480);

		auto vbox = new VBox(false, 0);

		this.menu = new MenuBar();
		this.connectItem = new MenuItem(&this.onConnectClick, "Connect");
		this.menu.append(connectItem);
		this.disconnectItem = new MenuItem(&this.onDisconnectClick, "Disconnect");
		this.menu.append(this.disconnectItem);
		vbox.packStart(this.menu, false, false, 0);

		this.notebook = new Notebook();
		this.notebook.setTabPos(GtkPositionType.TOP);

		this.logView = new ListBox();
		auto logScroll = new ScrolledWindow();
		logScroll.addWithViewport(this.logView);
		this.logView.addOnSizeAllocate((Allocation, Widget) {
			auto adj = logScroll.getVadjustment();
			adj.setValue(adj.getUpper() - adj.getPageSize());
		});
		this.notebook.appendPage(logScroll, "Log");

		vbox.packEnd(this.notebook, true, true, 0);

		this.add(vbox);

		this.connectWindow = new ConnectWindow(this);

		this.showAll();

		this.disconnectItem.setVisible(false);

		this.addTickCallback(&this.onTick);
		this.addOnDelete(&this.onDelete);

		this.log("Debugger: Started");
	}

	void onConnectClick(MenuItem)
	{
		this.connectWindow.makeVisible();
	}

	void onDisconnectClick(MenuItem)
	{
		if (!this.connection.isValid)
		{
			this.log("Emulator: Disconnect failed, no connection");
			return;
		}

		this.connection.shutdown(SocketShutdown.BOTH);
		this.connection.close();

		this.log("Emulator: Disconnected");

		this.connectItem.setVisible(true);
		this.disconnectItem.setVisible(false);

		foreach (ref core; this.cores)
			this.notebook.detachTab(core.widget);

		this.cores = [];
	}

	bool onTick(Widget, FrameClock)
	{
		this.handleSocket();

		return true;
	}

	bool onDelete(Event, Widget)
	{
		this.connection.shutdown(SocketShutdown.BOTH);
		this.connection.close();

		return false;
	}

	void start(string ipAddress, string port)
	{
		import std.socket : getAddress;

		this.log("Emulator: Connecting to %s:%s", ipAddress, port);
		auto address = getAddress(ipAddress, port.to!ushort)[0];
		this.connection = NonBlockingSocket(
			AddressFamily.INET, std.socket.SocketType.STREAM, ProtocolType.TCP);

		auto connectionAttempt = this.connection.connect(address);

		this.log("Emulator: Connection successful");
		this.connectItem.setVisible(false);
		this.disconnectItem.setVisible(true);
	}

	void sendMessage(T)(ref T message)
		if (isSerializableMessage!T)
	{
		auto buffer = StackBuffer!(T.sizeof)(message.length);
		this.connection.send(message.serialize(buffer));
	}

	void sendMessage(T, Args...)(auto ref Args args)
	{
		auto message = T(args);
		this.sendMessage(message);
	}

	void handleSocket()
	{
		if (!this.connection.isValid)
			return;

		ushort length;
		auto size = this.connection.receive(length);
		length = length.ntohs();

		if (size == 0)
		{
			this.log("Emulator: Disconnected");
			this.connection = NonBlockingSocket();
		}
		else if (size > 0)
		{
			auto buffer = StackBuffer!1024(length);
			auto readLeft = length;

			while (readLeft)
				readLeft -= this.connection.receive(buffer[(length - readLeft)..length]);

			this.handleMessage(buffer[0..length]);
		}
	}

	void createCore(uint index)
	{
		auto vbox = new VBox(false, 0);
		vbox.show();

		auto listStore = new ListStore(GType.INT.repeat(RegisterExtendedCount).array());
		auto iter = listStore.createIter();
		foreach (i; 0..RegisterExtendedCount)
			listStore.setValue(iter, i, 0);

		auto treeView = new TreeView();
		foreach (i; 0..RegisterExtendedCount)
		{
			string name = registerName(cast(Register)i);
			treeView.appendColumn(new TreeViewColumn(name, new CellRendererText(), "text", i));
		}

		treeView.setModel(listStore);

		auto treeScroll = new ScrolledWindow();
		treeScroll.add(treeView);
		vbox.packStart(treeScroll, true, true, 0);
		vbox.showAll();

		auto core = Core(index, vbox, listStore, iter);
		this.notebook.appendPage(core.widget, "Core %s".format(index));
		this.cores ~= core;

		this.sendMessage!CoreGetState(index);
	}

	void handleMessage(ubyte[] buffer)
	{
		auto messageId = cast(DebugMessageId)buffer[0];

		switch (messageId)
		{
		case DebugMessageId.Initialize:
			auto initialize = buffer.deserializeMessage!Initialize();

			foreach (coreIndex; 0 .. initialize.coreCount)
				this.createCore(coreIndex);

			this.sendMessage!SystemGetMemory(initialize.textBegin, initialize.textEnd);
			break;
		case DebugMessageId.CoreState:
			auto coreState = buffer.deserializeMessage!CoreState();

			auto core = &this.cores[coreState.core];
			core.running = coreState.running;
			core.registers = coreState.registers;
			core.updateUI();
			break;
		case DebugMessageId.SystemMemory:
			auto systemMemory = buffer.deserializeMessage!SystemMemory();

			auto opcodes = cast(Opcode[])systemMemory.memory;
			auto disassembly = opcodes.map!(a => a.disassemble());

			this.log("%s", disassembly);
			break;
		default:
			assert(0);
		}
	}

	void log(Args...)(string text, auto ref Args args)
	{
		import std.string, std.datetime;

		auto str = (cast(DateTime)Clock.currTime).toSimpleString();
		str ~= " | ";
		str ~= text.format(args);

		auto label = new Label(str);
		label.setAlignment(0, 0.5f);
		this.logView.insert(label, -1);
		this.logView.showAll();
	}
}

int main(string[] args)
{
	auto application = new Application(null, GApplicationFlags.NON_UNIQUE);
	application.addOnActivate((a) { new Debugger(application); });
	return application.run(args);
}
