module debugger_graphical.debuggerwindow;

import gtk.Application;

// Windows
import gtk.ApplicationWindow;
// Menu
import gtk.MenuBar, gtk.MenuItem;
// Display
import gtk.Label, gtk.ListBox;
// File choosing
import gtk.FileChooserDialog;
// Layout
import gtk.VBox, gtk.HBox, gtk.Notebook, gtk.ScrolledWindow;
// Other
import gtk.Widget, gdk.FrameClock, gdk.Event;

import std.string, std.range, std.algorithm, std.file;

import debugger_backend.backend;

import debugger_graphical.util;
import debugger_graphical.connectwindow;
import debugger_graphical.coretab;

class DebuggerWindow : ApplicationWindow
{
	Debugger debugger;

	MenuBar menu;
	ConnectWindow connectWindow;
	ListBox logView;

	MenuItem startItem;
	MenuItem connectItem;
	MenuItem disconnectItem;
	MenuItem shutdownItem;

	FileChooserDialog fileChooserDialog;

	Notebook notebook;

	CoreTab[] coreTabs;

	this(Application application)
	{
		super(application);
		this.setTitle("Skiron Debugger");
		this.setDefaultSize(640, 480);

		this.debugger = new Debugger();
		this.connectWindow = new ConnectWindow(this);

		this.fileChooserDialog = new FileChooserDialog("Open dialog", this, FileChooserAction.OPEN);
		this.fileChooserDialog.setCurrentFolder(getcwd());

		this.buildMenu();
		this.buildNotebook();
		this.buildLog();

		auto vbox = new VBox(false, 0);
		vbox.packStart(this.menu, false, false, 0);
		vbox.packEnd(this.notebook, true, true, 0);
		this.add(vbox);

		this.showAll();
		this.disconnectItem.setVisible(false);
		this.shutdownItem.setVisible(false);

		this.addTickCallback(&this.onTick);
		this.addOnDelete(&this.onDelete);
		this.installDebuggerCallbacks();

		this.log("Debugger: Started");
	}

	void buildMenu()
	{
		this.menu = new MenuBar();
		this.startItem = new MenuItem(&this.onStartClick, "Start");
		this.menu.append(this.startItem);
		this.connectItem = new MenuItem(&this.onConnectClick, "Connect");
		this.menu.append(this.connectItem);
		this.disconnectItem = new MenuItem(&this.onDisconnectClick, "Disconnect");
		this.menu.append(this.disconnectItem);
		this.shutdownItem = new MenuItem(&this.onShutdownClick, "Shutdown");
		this.menu.append(this.shutdownItem);
	}

	void buildNotebook()
	{
		this.notebook = new Notebook();
		this.notebook.setTabPos(GtkPositionType.TOP);
	}

	void buildLog()
	{
		this.logView = new ListBox();
		auto logScroll = new ScrolledWindow();
		logScroll.addWithViewport(this.logView);

		this.logView.addOnSizeAllocate((Allocation, Widget) {
			auto adj = logScroll.getVadjustment();
			adj.setValue(adj.getUpper() - adj.getPageSize());
		});

		this.notebook.appendPage(logScroll, "Log");
	}

	void installDebuggerCallbacks()
	{
		this.debugger.onInitialize = &this.onInitialize;
		this.debugger.onDisconnect = &this.onDisconnect;
		this.debugger.onCoreState = &this.onCoreState;
		this.debugger.onSystemOpcodes = &this.onSystemOpcodes;
	}

	void onStartClick(MenuItem)
	{
		if (this.fileChooserDialog.run() == ResponseType.OK)
		{
			this.fileChooserDialog.close();
			this.debugger.spawnEmulator(this.fileChooserDialog.getFilename());
		}
	}

	void onConnectClick(MenuItem)
	{
		this.connectWindow.makeVisible();
	}

	void onDisconnectClick(MenuItem)
	{
		this.debugger.disconnect();
	}

	void onShutdownClick(MenuItem)
	{
		this.debugger.shutdown();
	}

	void onInitialize()
	{
		foreach (ref core; this.debugger.cores)
		{	
			this.coreTabs ~= CoreTab(&core, this);
			auto coreTab = &this.coreTabs[$-1];
			coreTab.buildLayout();
			this.notebook.appendPage(coreTab.widget, "Core %s".format(core.index));
		}

		this.startItem.setVisible(false);
		this.connectItem.setVisible(false);
		this.disconnectItem.setVisible(true);
		this.shutdownItem.setVisible(true);
	}

	void onDisconnect()
	{
		this.log("Emulator: Disconnected");

		this.startItem.setVisible(true);
		this.connectItem.setVisible(true);
		this.disconnectItem.setVisible(false);
		this.shutdownItem.setVisible(false);

		foreach (ref coreTab; this.coreTabs)
			this.notebook.detachTab(coreTab.widget);

		this.coreTabs = [];
	}

	void onCoreState(Core* core)
	{
		this.coreTabs[core.index].update();
	}

	void onSystemOpcodes()
	{	
		foreach (ref coreTab; this.coreTabs)
			coreTab.loadOpcodes(this.debugger.opcodes);
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