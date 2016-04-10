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
// Pango
import pango.PgAttributeList, pango.PgAttribute;

import std.string, std.range, std.algorithm;

import debugger_backend.backend;

void setMargin(Widget widget, uint margin)
{
	widget.setMarginTop(margin);
	widget.setMarginBottom(margin);
	widget.setMarginStart(margin);
	widget.setMarginEnd(margin);
}

struct CoreTab
{
	Core* core;
	DebuggerWindow parent;

	Widget widget;

	ListStore generalStore;
	TreeIter generalIter;

	ListStore standardStore;
	TreeIter standardIter;

	MenuBar menu;
	MenuItem pauseResumeItem;
	MenuItem stepItem;

	Label runningLabel;

	ListBox instructionList;
	Label lastIpLabel;
	PgAttributeList defaultAttributes;
	PgAttributeList highlightedAttributes;

	this(Core* core, DebuggerWindow parent)
	{
		this.core = core;
		this.parent = parent;

		this.defaultAttributes = new PgAttributeList();
		this.highlightedAttributes = this.defaultAttributes.copy();
		this.highlightedAttributes.change(PgAttribute.weightNew(PangoWeight.SEMIBOLD));
	}

	// Separate from the constructor as we need access to the final this pointer
	void buildLayout()
	{
		auto vbox = new VBox(false, 0);

		this.instructionList = new ListBox();
		auto instructionScroll = new ScrolledWindow();
		instructionScroll.addWithViewport(instructionList);
		auto instructionFrame = new Frame("Instruction List");
		instructionFrame.add(instructionScroll);
		instructionFrame.setMargin(4);

		this.menu = new MenuBar();
		this.pauseResumeItem = new MenuItem(&this.onPauseResumeClick, "Pause/Resume");
		this.stepItem = new MenuItem(&this.onStepClick, "Step");
		this.menu.append(this.pauseResumeItem);
		this.menu.append(this.stepItem);

		this.runningLabel = new Label("");
		this.runningLabel.setAlignment(0, 0.5f);
		this.runningLabel.setPadding(4, 4);

		vbox.packStart(this.menu, false, false, 0);
		vbox.packStart(instructionFrame, true, true, 0);
		vbox.packEnd(this.runningLabel, false, false, 0);

		auto registersVbox = new VBox(false, 0);
		registersVbox.packStart(this.buildGeneralRegisters(), true, true, 0);
		registersVbox.packEnd(this.buildStandardRegisters(), true, true, 0);

		auto registersFrame = new Frame("Registers");
		registersFrame.add(registersVbox);
		registersFrame.setMargin(4);

		vbox.packEnd(registersFrame, true, true, 0);
		vbox.showAll();

		this.widget = vbox;
	}

	enum GeneralMax = cast(uint)Register.min;
	enum StandardMin = GeneralMax;
	enum StandardMax = RegisterExtendedCount;
	enum StandardCount = StandardMax - StandardMin;

	ScrolledWindow buildGeneralRegisters()
	{
		this.generalStore = 
			new ListStore(GType.INT.repeat(GeneralMax).array());

		this.generalIter = this.generalStore.createIter();

		foreach (i; 0..GeneralMax)
			this.generalStore.setValue(this.generalIter, i, 0);

		auto treeView = new TreeView();
		foreach (i; 0..GeneralMax)
		{
			string name = registerName(cast(Register)i);
			treeView.appendColumn(
				new TreeViewColumn(name, new CellRendererText(), "text", i));
		}

		treeView.setModel(this.generalStore);

		auto treeScroll = new ScrolledWindow();
		treeScroll.add(treeView);

		return treeScroll;
	}

	ScrolledWindow buildStandardRegisters()
	{
		this.standardStore = 
			new ListStore(GType.INT.repeat(StandardCount).array());

		this.standardIter = this.standardStore.createIter();

		foreach (i; 0..StandardCount)
			this.standardStore.setValue(this.standardIter, i, 0);

		auto treeView = new TreeView();
		foreach (i; StandardMin..StandardMax)
		{
			string name = registerName(cast(Register)i);
			treeView.appendColumn(
				new TreeViewColumn(name, new CellRendererText(), "text", i - StandardMin));
		}

		treeView.setModel(this.standardStore);

		auto treeScroll = new ScrolledWindow();
		treeScroll.add(treeView);

		return treeScroll;
	}

	void update()
	{
		foreach (index, value; this.core.registers)
		{
			if (index < GeneralMax)
				this.generalStore.setValue(this.generalIter, index, value);
			else
				this.standardStore.setValue(this.standardIter, index - StandardMin, value);
		}

		this.runningLabel.setText(this.core.running ? "Running" : "Paused");
		this.pauseResumeItem.setLabel(this.core.running ? "Pause" : "Resume");
		this.stepItem.setVisible(!this.core.running);

		this.updateIpLabel();
	}

	void updateIpLabel()
	{
		// Get the index for the row of the current IP
		uint index = (this.core.registers[Register.IP] - this.parent.debugger.textBegin) / Opcode.sizeof;
		auto row = this.instructionList.getRowAtIndex(index);

		// Bail out if not available
		if (row is null)
			return;

		// Update the attributes
		auto ipLabel = cast(Label)row.getChild();

		ipLabel.setAttributes(this.highlightedAttributes);

		// Reset the last IP label
		if (this.lastIpLabel)
			this.lastIpLabel.setAttributes(this.defaultAttributes);

		this.lastIpLabel = ipLabel;
	}

	void onPauseResumeClick(MenuItem item)
	{
		this.core.setRunning(!this.core.running);
	}

	void onStepClick(MenuItem item)
	{
		this.core.step();
	}

	void loadOpcodes(Opcode[] opcodes)
	{
		foreach (index, opcode; opcodes.enumerate)
		{
			auto str = "0x%08X: %s".format(
				this.parent.debugger.textBegin + (index * Opcode.sizeof),
				opcode.disassemble());

			auto label = new Label(str);
			label.setAlignment(0, 0.5f);
			this.instructionList.insert(label, -1);
			label.show();
		}

		this.update();
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
		this.connectWindow = new ConnectWindow(this);

		this.buildMenu();
		this.buildNotebook();
		this.buildLog();

		auto vbox = new VBox(false, 0);
		vbox.packStart(this.menu, false, false, 0);
		vbox.packEnd(this.notebook, true, true, 0);
		this.add(vbox);

		this.showAll();
		this.disconnectItem.setVisible(false);

		this.addTickCallback(&this.onTick);
		this.addOnDelete(&this.onDelete);
		this.installDebuggerCallbacks();

		this.log("Debugger: Started");
	}

	void buildMenu()
	{
		this.menu = new MenuBar();
		this.connectItem = new MenuItem(&this.onConnectClick, "Connect");
		this.menu.append(connectItem);
		this.disconnectItem = new MenuItem(&this.onDisconnectClick, "Disconnect");
		this.menu.append(this.disconnectItem);
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
		this.debugger.onSystemMemory = (address, bytes) {};
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
		{	
			this.coreTabs ~= CoreTab(&core, this);
			auto coreTab = &this.coreTabs[$-1];
			coreTab.buildLayout();
			this.notebook.appendPage(coreTab.widget, "Core %s".format(core.index));
		}

		this.connectItem.setVisible(false);
		this.disconnectItem.setVisible(true);
	}

	void onDisconnect()
	{
		this.log("Emulator: Disconnected");

		this.connectItem.setVisible(true);
		this.disconnectItem.setVisible(false);

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

int main(string[] args)
{
	auto application = new Application(null, GApplicationFlags.NON_UNIQUE);
	application.addOnActivate((a) { new DebuggerWindow(application); });
	return application.run(args);
}
