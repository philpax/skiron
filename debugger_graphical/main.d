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

import std.string, std.range, std.algorithm;

import debugger_backend.backend;

struct CoreTab
{
	Core* core;
	Widget widget;
	ListStore listStore;
	TreeIter iter;

	ListBox instructionList;
	Label runningLabel;

	void update()
	{
		foreach (index, value; this.core.registers)
			this.listStore.setValue(iter, index, value);

		this.runningLabel.setText(this.core.running ? "Running" : "Paused");
	}
}

class ConnectWindow : Window
{
	Entry ipAddressEntry;
	Entry portEntry;
	Button button;

	DebuggerWindow debugger;

	this(DebuggerWindow debugger)
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

class DebuggerWindow : ApplicationWindow
{
	Debugger debugger;

	MenuBar menu;
	ConnectWindow connectWindow;
	ListBox logView;

	MenuItem connectItem;
	MenuItem disconnectItem;

	Notebook notebook;

	CoreTab[] coreTabs;

	this(Application application)
	{
		super(application);
		this.setTitle("Skiron Debugger");
		this.setDefaultSize(640, 480);

		this.debugger = new Debugger();

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

		this.debugger.onInitialize = &this.onInitialize;
		this.debugger.onDisconnect = &this.onDisconnect;
		this.debugger.onCoreState = &this.onCoreState;
		this.debugger.onSystemOpcodes = &this.onSystemOpcodes;
		this.debugger.onSystemMemory = (address, bytes) {};

		this.log("Debugger: Started");
	}

	void onConnectClick(MenuItem)
	{
		this.connectWindow.makeVisible();
	}

	void onDisconnectClick(MenuItem)
	{
		this.debugger.disconnect();
	}

	void onInitialize()
	{
		foreach (ref core; this.debugger.cores)
			this.createCoreTab(core);

		this.connectItem.setVisible(false);
		this.disconnectItem.setVisible(true);
	}

	void onDisconnect()
	{
		this.log("Emulator: Disconnected");

		this.connectItem.setVisible(true);
		this.disconnectItem.setVisible(false);

		foreach (ref core; this.coreTabs)
			this.notebook.detachTab(core.widget);

		this.coreTabs = [];
	}

	void onCoreState(Core* core)
	{
		this.coreTabs[core.index].update();
	}

	void onSystemOpcodes()
	{	
		foreach (ref coreTab; this.coreTabs)
		{
			foreach (index, opcode; this.debugger.opcodes.enumerate)
			{
				auto str = "0x%08X: %s".format(
					this.debugger.textBegin + (index * Opcode.sizeof),
					opcode.disassemble());

				auto label = new Label(str);
				label.setAlignment(0, 0.5f);
				coreTab.instructionList.insert(label, -1);
				label.show();
			}
		}
	}

	bool onTick(Widget, FrameClock)
	{
		this.debugger.handleSocket();

		return true;
	}

	bool onDelete(Event, Widget)
	{
		this.debugger.disconnect();

		return false;
	}

	void start(string ipAddress, string port)
	{
		this.log("Emulator: Connecting to %s:%s", ipAddress, port);
		this.debugger.connect(ipAddress, port);
	}

	void createCoreTab(ref Core core)
	{
		auto index = core.index;

		auto vbox = new VBox(false, 0);
		vbox.show();

		auto instructionView = new ListBox();
		auto instructionScroll = new ScrolledWindow();
		instructionScroll.addWithViewport(instructionView);

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

		auto menu = new MenuBar();
		menu.append(new MenuItem((item) {
			auto debuggerCore = this.coreTabs[index].core;
			debuggerCore.setRunning(!debuggerCore.running);
		}, "Pause/Resume"));

		auto runningLabel = new Label("");
		runningLabel.setAlignment(0, 0.5f);
		runningLabel.setPadding(4, 4);

		vbox.packStart(menu, false, false, 0);
		vbox.packStart(instructionScroll, true, true, 0);
		vbox.packEnd(runningLabel, false, false, 0);
		vbox.packEnd(treeScroll, true, true, 0);
		vbox.showAll();

		auto coreTab = CoreTab(&core, vbox, listStore, iter, instructionView, runningLabel);
		this.notebook.appendPage(coreTab.widget, "Core %s".format(index));
		this.coreTabs ~= coreTab;
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
	application.addOnActivate((a) { new DebuggerWindow(application); });
	return application.run(args);
}
