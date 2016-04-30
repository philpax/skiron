module debugger_graphical.coretab;

// Menu
import gtk.MenuBar, gtk.MenuItem;
// Display
import gtk.Label, gtk.ListBox;
// Layout
import gtk.VBox, gtk.ScrolledWindow, gtk.Frame;
// Other
import gtk.Widget;
// TreeView
import gtk.ListStore, gtk.TreeView, gtk.TreeViewColumn, gtk.CellRendererText, gtk.TreeIter;
// Pango
import pango.PgAttributeList, pango.PgAttribute;

import std.string, std.range, std.algorithm, std.file;

import debugger_backend.backend;

import debugger_graphical.debuggerwindow;
import debugger_graphical.util;

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

		row.activate();

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