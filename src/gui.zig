const std = @import("std");
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx_impl = @import("gfx_impl.zig");

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const GuiError = error{
    GuiUnknownOverlay,
    GuiUnknownWidget,
    GuiWidgetCastingFailed,
    GuiWidgetNoOverlay,
};

const AlignH = enum {
    none,
    centered,
    left,
    right,
};

const AlignV = enum {
    none,
    centered,
    top,
    bottom,
};

const OverlayResizeMode = enum {
    none,
    auto,
    auto_vertical,
};

pub const Title = struct {
    text: []const u8 = "Title",
    font_name: []const u8 = "anka_b",
    font_size: f32 = 32,
    col: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
    frame: f32 = 10.0,
    alignment: AlignH = .centered,
    is_enabled: bool = true,
    is_separator_enabled: bool = true,
    separator_thickness: f32 = 1.0,
};

pub const TextWidget = struct {
    overlay: ?*Overlay = null,
    text: []const u8 = "TextWidget",
    font_name: []const u8 = "anka_r",
    font_size: f32 = 32
        ,

    col: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
    align_h: AlignH = .centered,
    align_v: AlignV = .centered,

    fn draw(self: *TextWidget) !void {
        if (self.overlay == null) {
            gui_log.err("Widget is not bound to overlay", .{});
            return error.GuiWidgetNoOverlay;
        }
        var ovl = self.overlay.?;
        var x_a: f32 = 0.0;
        var y_a: f32 = 0.0;
        var wrap: f32 = 0.0;
        const rm = ovl.resize_mode;
        if (rm == .none or rm == .auto_vertical) wrap = ovl.width - ovl.frame[0] - ovl.frame[2];
        const s = try fnt.getTextSize(self.text, wrap);
        if (rm == .auto) {
            ovl.width = s.w + ovl.frame[0] + ovl.frame[2];
        }
        if (rm == .auto or rm == .auto_vertical) {
            ovl.height = s.h + ovl.frame[1] + ovl.frame[3] + ovl.title.font_size;
        }
        switch (self.align_h) {
            .centered => {
                x_a = (ovl.width - s.w) * 0.5 + ovl.ll_x;
            },
            .left, .none => {
                x_a = ovl.ll_x + ovl.frame[0];
            },
            .right => {
                x_a = ovl.ll_x + ovl.width - ovl.frame[2] - s.w;
            },
        }
        switch (self.align_v) {
            .centered => {
                y_a = (ovl.height - ovl.title.font_size - s.h) * 0.5 + ovl.ll_y + ovl.title.font_size;
            },
            .bottom => {
                y_a = ovl.ll_y + ovl.height - ovl.frame[3] - s.h;
            },
            .top, .none => {
                y_a = ovl.ll_y + ovl.title.font_size + ovl.frame[1];
            },
        }
        try fnt.renderText(self.text, x_a, y_a, wrap);
    }
};

pub const Overlay = struct {
    name: []const u8 = "Overlay",
    width: f32 = 100.0,
    height: f32 = 100.0,
    resize_mode: OverlayResizeMode = .auto,
    align_h: AlignH = .none,
    align_v: AlignV = .none,
    align_border: f32 = 10.0,
    is_enabled: bool = true,
    is_focussed: bool = true,
    ll_x: f32 = 0.0,
    ll_y: f32 = 0.0,
    col: [4]f32 = .{ 1.0, 1.0, 1.0, 1.0 },
    title: Title = .{},
    frame: [4]f32 = .{ 10.0, 10.0, 10.0, 10.0 },
    widget: ?*anyopaque = null,
    widget_type: WidgetType = .none,
};

pub fn addOverlay(name: []const u8, overlay: Overlay) !void {
    try overlays.append(overlay);
    const ovl = &overlays.items[overlays.items.len - 1];
    try overlays_sorted.append(ovl);
    ovl.name = name;
    try overlays_by_name.put(name, ovl);
}

pub fn addTextWidget(name_ol: []const u8, name_tw: []const u8, tw: TextWidget) !void {
    try text_widgets.put(name_tw, tw);
    const ol = overlays_by_name.get(name_ol) orelse {
        _ = text_widgets.remove(name_tw);
        gui_log.err("Unknown overlay <{s}>, cannot add widget", .{name_ol});
        return error.GuiUnknownOverlay;
    };
    ol.widget = text_widgets.getPtr(name_tw).?;
    ol.widget_type = .text;
    text_widgets.getPtr(name_tw).?.overlay = ol;
}

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn deinit() void {
    overlays.deinit();
    overlays_sorted.deinit();
    overlays_by_name.deinit();
    text_widgets.deinit();

    const leaked = gpa.deinit();
    if (leaked) std.log.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn getOverlay(name: []const u8) GuiError!*Overlay {
    return overlays_by_name.get(name) orelse {
        gui_log.err("Unknown overlay <{s}>", .{name});
        return error.GuiUnknownOverlay;
    };
}

pub inline fn getTextWidget(name: []const u8) GuiError!*TextWidget {
    return text_widgets.getPtr(name) orelse {
        gui_log.err("Unknown text widget <{s}>", .{name});
        return error.GuiUnknownWidget;
    };
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn drawCursor(x: f32, y: f32) void {
    const cursor_size = 15;
    const cursor_gap_center = 5;
    const cursor_thickness = 3;
    if (is_cursor_visible) {
        gfx_impl.setColor(0.2, 1.0, 0.2, 0.5);
        gfx_impl.setLineWidth(cursor_thickness);
        gfx_impl.addImmediateLine(x - cursor_size, y, x - cursor_gap_center, y);
        gfx_impl.addImmediateLine(x + cursor_gap_center, y, x + cursor_size, y);
        gfx_impl.addImmediateLine(x, y - cursor_size, x, y - cursor_gap_center);
        gfx_impl.addImmediateLine(x, y + cursor_gap_center, x, y + cursor_size);
    }
}

pub fn drawOverlay(ovl: *Overlay) !void {
    const win_w = @intToFloat(f32, gfx_impl.getWindowWidth());
    const win_h = @intToFloat(f32, gfx_impl.getWindowHeight());

    switch (ovl.align_h) {
        .centered => {
            ovl.ll_x = (win_w - ovl.width) * 0.5;
        },
        .left => {
            ovl.ll_x = ovl.align_border;
        },
        .right => {
            ovl.ll_x = win_w - ovl.width - ovl.align_border;
        },
        else => {},
    }
    switch (ovl.align_v) {
        .centered => {
            ovl.ll_y = (win_h - ovl.height) * 0.5;
        },
        .top => {
            ovl.ll_y = ovl.align_border;
        },
        .bottom => {
            ovl.ll_y = win_h - ovl.height - ovl.align_border;
        },
        else => {},
    }

    gfx_impl.setColor(ovl.col[0], ovl.col[1], ovl.col[2], ovl.col[3]);
    gfx_impl.addImmediateQuad(ovl.ll_x, ovl.ll_y, ovl.ll_x + ovl.width, ovl.ll_y + ovl.height);

    //----------------
    // Draw the title
    //----------------
    if (ovl.title.is_enabled) {
        try fnt.setFont(ovl.title.font_name, ovl.title.font_size);
        var title_x = ovl.ll_x;
        switch (ovl.title.alignment) {
            .centered => {
                const s = try fnt.getTextSizeLine(ovl.title.text);
                title_x = ovl.ll_x + (ovl.width - s.w) * 0.5;
            },
            .left, .none => {
                title_x += ovl.title.frame;
            },
            .right => {
                const s = try fnt.getTextSizeLine(ovl.title.text);
                title_x = ovl.ll_x + ovl.width - s.w - ovl.title.frame;
            },
        }
        gfx_impl.setColor(ovl.title.col[0], ovl.title.col[1], ovl.title.col[2], ovl.title.col[3]);
        try fnt.renderText(ovl.title.text, title_x, ovl.ll_y, 0.0);

        if (ovl.title.is_separator_enabled) {
            gfx_impl.setLineWidth(ovl.title.separator_thickness);
            gfx_impl.addImmediateLine(ovl.ll_x + ovl.title.frame, ovl.ll_y + ovl.title.font_size, ovl.ll_x + ovl.width - ovl.title.frame, ovl.ll_y + ovl.title.font_size);
        }
    }
    if (ovl.is_focussed) {
        gfx_impl.setColor(ovl.title.col[0], ovl.title.col[1], ovl.title.col[2], ovl.title.col[3]);
        gfx_impl.setLineWidth(1.0);
        gfx_impl.addImmediateLine(ovl.ll_x, ovl.ll_y, ovl.ll_x + ovl.width, ovl.ll_y);
        gfx_impl.addImmediateLine(ovl.ll_x + ovl.width, ovl.ll_y, ovl.ll_x + ovl.width, ovl.ll_y + ovl.height);
        gfx_impl.addImmediateLine(ovl.ll_x, ovl.ll_y + ovl.height, ovl.ll_x + ovl.width, ovl.ll_y + ovl.height);
        gfx_impl.addImmediateLine(ovl.ll_x, ovl.ll_y, ovl.ll_x, ovl.ll_y + ovl.height);
    }

    if (ovl.widget_type == .text and ovl.widget != null) {
        const tw = @ptrCast(?*TextWidget, @alignCast(@alignOf(TextWidget), ovl.widget)) orelse {
            gui_log.err("Unable to access widget for drawing", .{});
            return error.GuiWidgetCastFailed;
        };
        try fnt.setFont(tw.font_name, tw.font_size);
        gfx_impl.setColor(tw.col[0], tw.col[1], tw.col[2], tw.col[3]);
        try tw.draw();
    }
}

pub fn processOverlays(x: f32, y: f32, mouse_l: bool, mouse_wheel: f32) !void {
    _ = mouse_wheel;

    // Get relative mouse movement
    edit_mode.mouse_dx = x - edit_mode.mouse_x_prev;
    edit_mode.mouse_dy = y - edit_mode.mouse_y_prev;

    //-----------------------------------------------------------
    // Overlay manipulation
    // (only relevant in edit mode if left mouse button pressed)
    //-----------------------------------------------------------
    if (edit_mode.is_enabled and mouse_l) {
        // In the array of sorted overlays the last entry is the foremost one, since it
        // is drawn last and hence, will be focussed first
        edit_mode.overlay_focussed = overlays_sorted.items[overlays_sorted.items.len - 1];

        // Starting from the foremost, focussed overlay, go back and check, if the mouse
        // cursor is within that overlay
        var j: i64 = @intCast(i64, overlays_sorted.items.len - 1);
        while (j >= 0) : (j -= 1) {
            var i: usize = @intCast(usize, j);
            const ovl = overlays_sorted.items[i];
            const x_p = edit_mode.mouse_x_prev;
            const y_p = edit_mode.mouse_y_prev;

                if (x_p > ovl.ll_x and x_p < ovl.ll_x + ovl.width and
                    y_p > ovl.ll_y and y_p < ovl.ll_y + ovl.height and
                    ovl.is_enabled)
                {
                    // If mouse button has just been pressed, change the focus
                    if (!edit_mode.mouse_l_prev) {
                        std.mem.swap(*Overlay, &overlays_sorted.items[i], &overlays_sorted.items[overlays_sorted.items.len - 1]);
                        edit_mode.overlay_focussed = overlays_sorted.items[overlays_sorted.items.len - 1];
                    }
                    // Move overlay if inside focussed overlay
                    if (edit_mode.overlay_focussed == ovl) {
                        moveOverlay(overlays_sorted.items[overlays_sorted.items.len - 1],
                                    edit_mode.mouse_dx, edit_mode.mouse_dy);
                    }
                    break;
                } else {
                    ovl.is_focussed = false;
                }
        }
    }

    // Draw all overlays in sorted order
    for (overlays_sorted.items) |ovl| {
        // In edit mode, enable focus on the accordant overlay,
        // otherwise disable focus
        if (edit_mode.overlay_focussed == ovl and
            edit_mode.is_enabled) {
            ovl.is_focussed = true;
        } else ovl.is_focussed = false;

        // Draw enabled overlays
        if (ovl.is_enabled) try drawOverlay(ovl);
    }

    edit_mode.mouse_x_prev = x;
    edit_mode.mouse_y_prev = y;
    edit_mode.mouse_l_prev = mouse_l;
}

pub fn toggleEditMode() void {
    edit_mode.is_enabled = edit_mode.is_enabled != true;

    if (edit_mode.is_enabled) {
        is_cursor_visible = true;
    } else {
        is_cursor_visible = false;
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

/// Font manager logging scope
const gui_log = std.log.scoped(.fnt);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var is_cursor_visible: bool = false;

const snapping = struct {
    var border: f32 = 30.0;
    var release: f32 = 1.0;
    var is_enabled: bool = true;
};

const WidgetType = enum {
    none,
    text,
};

var overlays = std.ArrayList(Overlay).init(allocator);
var overlays_sorted = std.ArrayList(*Overlay).init(allocator);
var overlays_by_name = std.StringHashMap(*Overlay).init(allocator);
var text_widgets = std.StringHashMap(TextWidget).init(allocator);

const edit_mode = struct {
    var is_enabled: bool = false;
    var overlay_focussed: ?*Overlay = null;
    var overlay_focussed_prev: ?*Overlay = null;
    var mouse_x_prev: f32 = 0.0;
    var mouse_y_prev: f32 = 0.0;
    var mouse_l_prev: bool = false;
    var mouse_dx: f32 = 0.0;
    var mouse_dy: f32 = 0.0;
};

fn moveOverlay(ovl: *Overlay, x: f32, y: f32) void {
    ovl.ll_x += x;
    ovl.ll_y += y;
    if (snapping.is_enabled) {
        const win_w = @intToFloat(f32, gfx_impl.getWindowWidth());
        const win_h = @intToFloat(f32, gfx_impl.getWindowHeight());

        const c_x = ovl.ll_x + ovl.width * 0.5 - win_w * 0.5;
        const c_y = ovl.ll_y + ovl.height * 0.5 - win_h * 0.5;

        if (ovl.ll_x < snapping.border and edit_mode.mouse_dx < snapping.release) {
            ovl.align_h = .left;
        } else if (ovl.ll_x > win_w - ovl.width - snapping.border and edit_mode.mouse_dx > -snapping.release) {
            ovl.align_h = .right;
        } else if (c_x >= 0.0 and c_x < snapping.border and edit_mode.mouse_dx < snapping.release) {
            ovl.align_h = .centered;
        } else if (c_x < 0.0 and c_x > -snapping.border and edit_mode.mouse_dx > -snapping.release) {
            ovl.align_h = .centered;
        } else {
            ovl.align_h = .none;
        }

        if (ovl.ll_y < snapping.border and edit_mode.mouse_dy < snapping.release) {
            ovl.align_v = .top;
        } else if (ovl.ll_y > win_h - ovl.height - snapping.border and edit_mode.mouse_dy > -snapping.release) {
            ovl.align_v = .bottom;
        } else if (c_y >= 0.0 and c_y < snapping.border and edit_mode.mouse_dy < snapping.release) {
            ovl.align_v = .centered;
        } else if (c_y < 0.0 and c_y > -snapping.border and edit_mode.mouse_dy > -snapping.release) {
            ovl.align_v = .centered;
        } else {
            ovl.align_v = .none;
        }
    } else {
        ovl.align_h = .none;
        ovl.align_v = .none;
    }
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "gui: add widget (failure)" {
    const w = TextWidget{};
    const actual = addTextWidget("non_existing_overlay", "widget", w);
    const expected = GuiError.GuiUnknownOverlay;
    try std.testing.expectError(expected, actual);
    try std.testing.expectEqual(overlays.items.len, 0);
    try std.testing.expectEqual(overlays_sorted.items.len, 0);
    try std.testing.expectEqual(overlays_by_name.count(), 0);
    try std.testing.expectEqual(text_widgets.count(), 0);
}

test "gui: get overlay (failure)" {
    const actual = getOverlay("non_existing_overlay");
    const expected = GuiError.GuiUnknownOverlay;
    try std.testing.expectError(expected, actual);
}

test "gui: get widget (failure)" {
    const actual = getTextWidget("non_existing_widget");
    const expected = GuiError.GuiUnknownWidget;
    try std.testing.expectError(expected, actual);
}

test "gui: add overlay" {
    const ovl = Overlay{};
    try addOverlay("valid_overlay", ovl);
    try std.testing.expectEqual(overlays.items.len, 1);
    try std.testing.expectEqual(overlays_sorted.items.len, 1);
    try std.testing.expectEqual(overlays_by_name.count(), 1);
    try std.testing.expectEqual(text_widgets.count(), 0);
}

test "gui: add text widget" {
    const w = TextWidget{};
    try addTextWidget("valid_overlay", "valid_widget", w);
    try std.testing.expectEqual(overlays.items.len, 1);
    try std.testing.expectEqual(overlays_sorted.items.len, 1);
    try std.testing.expectEqual(overlays_by_name.count(), 1);
    try std.testing.expectEqual(text_widgets.count(), 1);
}

test "gui: draw text widget (failure)" {
    var w = TextWidget{};
    const actual = w.draw();
    const expected = GuiError.GuiWidgetNoOverlay;
    try std.testing.expectError(expected, actual);
}

test "gui: toggle edit mode" {
    edit_mode.is_enabled = true;
    toggleEditMode();
    try std.testing.expectEqual(edit_mode.is_enabled, false);
    try std.testing.expectEqual(is_cursor_visible, false);
    toggleEditMode();
    try std.testing.expectEqual(edit_mode.is_enabled, true);
    try std.testing.expectEqual(is_cursor_visible, true);
}
