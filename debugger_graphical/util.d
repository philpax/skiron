module debugger_graphical.util;

import gtk.Widget;

void setMargin(Widget widget, uint margin)
{
	widget.setMarginTop(margin);
	widget.setMarginBottom(margin);
	widget.setMarginStart(margin);
	widget.setMarginEnd(margin);
}