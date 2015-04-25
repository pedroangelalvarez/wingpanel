/*-
 * Copyright (c) 2015 Wingpanel Developers (http://launchpad.net/wingpanel)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Library General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

public class Wingpanel.PanelWindow : Gtk.Window {
	private const int INTENDED_SIZE = 30;

	private Widgets.Panel panel;

	private Services.PopoverManager popover_manager;

	private Gdk.Rectangle scr;
	private Gdk.Rectangle small_scr;
	private Gdk.Rectangle orig_scr;

	private bool expanded = true;

	private int position_x;
	private int position_y;

	private int panel_displacement;

	public PanelWindow () {
		this.decorated = false;
		this.resizable = false;
		this.skip_taskbar_hint = true;
		this.app_paintable = true;
		this.type_hint = Gdk.WindowTypeHint.DOCK;
		this.vexpand = false;

		var style_context = get_style_context ();
		style_context.add_class ("panel");
		style_context.add_class (Gtk.STYLE_CLASS_MENUBAR);

		this.screen.size_changed.connect (update_panel_size);
		this.screen.monitors_changed.connect (update_panel_size);
		this.screen_changed.connect (update_visual);

		this.get_position (out position_x, out position_y);

		update_panel_size ();
		update_visual ();

		popover_manager = new Services.PopoverManager (this);

		panel = new Widgets.Panel (popover_manager, INTENDED_SIZE);
		panel.realize.connect (() => { 
			panel.get_preferred_height (out panel_displacement, null);
			panel_displacement *= -1;

			Timeout.add (300 / panel_displacement * (-1), animation_step);
		});

		this.add (panel);

		var monitor = screen.get_primary_monitor ();
		screen.get_monitor_geometry (monitor, out orig_scr);

		small_scr = orig_scr;
		small_scr.height = INTENDED_SIZE;

		scr = small_scr;

		set_expanded (false);
	}

	private bool animation_step () {
		if (panel_displacement >= 0)
			return false;

		panel_displacement++;

		this.move (position_x, position_y + panel_displacement);

		update_struts ();

		return true;
	}

	private void update_panel_size () {
		Gdk.Rectangle monitor_dimensions;
		this.screen.get_monitor_geometry (this.screen.get_primary_monitor (), out monitor_dimensions);

		this.set_size_request (monitor_dimensions.width, -1);

		update_struts ();
	}

	private void update_visual () {
		var visual = this.screen.get_rgba_visual ();

		if (visual == null)
			warning ("Compositing not available, things will Look Bad (TM)");
		else
			this.set_visual (visual);
	}

	private void update_struts () {
		if (!this.get_realized () || panel == null)
			return;

		int panel_size;

		panel.get_preferred_height (out panel_size, null);

		panel_size += panel_displacement;

		Gdk.Atom atom;
		Gdk.Rectangle primary_monitor_rect;

		long struts[12];

		var screen = this.screen;
		var monitor = screen.get_primary_monitor ();

		screen.get_monitor_geometry (monitor, out primary_monitor_rect);

		struts = {0, 0, primary_monitor_rect.y + panel_size, 0, // strut-left, strut-right, strut-top, strut-bottom
				0, 0, // strut-left-start-y, strut-left-end-y
				0, 0, // strut-right-start-y, strut-right-end-y
				primary_monitor_rect.x, primary_monitor_rect.x + primary_monitor_rect.width -1, // strut-top-start-x, strut-top-end-x
				0, 0}; // strut-bottom-start-x, strut-bottom-end-x

		atom = Gdk.Atom.intern ("_NET_WM_STRUT_PARTIAL", false);

		Gdk.property_change (this.get_window (), atom, Gdk.Atom.intern ("CARDINAL", false),
				32, Gdk.PropMode.REPLACE, (uint8[])struts, 12);
	}

	public void set_expanded (bool expanded) {
		if (this.expanded == expanded)
			return;

		this.expanded = expanded;

		if (!expanded)
			scr = small_scr;
		else
			scr = orig_scr;

		queue_resize ();

		if (expanded)
			present ();
	}

	public override void get_preferred_width (out int m, out int n) {
		m = scr.width;
		n = scr.width;
	}

	public override void get_preferred_width_for_height (int h, out int m, out int n) {
		m = scr.width;
		n = scr.width;
	}

	public override void get_preferred_height (out int m, out int n) {
		m = scr.height;
		n = scr.height;
	}

	public override void get_preferred_height_for_width (int w, out int m, out int n) {
		m = scr.height;
		n = scr.height;
	}
}
