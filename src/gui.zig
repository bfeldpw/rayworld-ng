const std = @import("std");
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx_impl = @import("gfx_impl.zig");

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const GuiError = error {
    GuiUnknownOverlay,
    GuiUnknownWidget,
    GuiWidgetCastingFailed,
    GuiWidgetNoOverlay,
};

const AlignmentHorizontal = enum {
    centered,
    left,
    right,
};

const AlignmentVertical = enum {
    centered,
    top,
    bottom,
};

const OverlayResizeMode = enum {
    none,
    auto,
};

pub const Title = struct {
    text: []const u8 = "Title",
    font_name: []const u8 = "anka_b",
    font_size: f32 = 32,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    frame: f32 = 10.0,
    alignment: AlignmentHorizontal = .centered,
    is_enabled: bool = true,
    is_separator_enabled: bool = true,
    separator_thickness: f32 = 1.0,
};

pub const TextWidget = struct {
    overlay: ?*ParamOverlay = null,
    text: []const u8 = "TextWidget",
    font_name: []const u8 = "anka_r",
    font_size: f32 = 32,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    align_h: AlignmentHorizontal = .centered,
    align_v: AlignmentVertical = .centered,

    // fn draw(self: *TextWidget, x: f32, y: f32) !void {
    fn draw(self: *TextWidget) !void {
        if (self.overlay == null) {
            gui_log.err("Widget is not bound to overlay", .{});
            return error.GuiWidgetNoOverlay;
        }
        var ovl = self.overlay.?;
        var x_a: f32 = 0.0;
        var y_a: f32 = 0.0;
        const s = try fnt.getTextSize(self.text);
        if (ovl.resize_mode == .auto) {
            ovl.width = s.w + ovl.frame[0] + ovl.frame[2];
            ovl.height = s.h + ovl.frame[1] + ovl.frame[3] + ovl.title.font_size;
        }
        switch (self.align_h) {
            .centered => {
                x_a = (ovl.width - s.w) * 0.5 + ovl.ll_x;
            },
            .left => {
                x_a = ovl.ll_x + ovl.frame[0];
            },
            .right => {
                x_a = ovl.ll_x + ovl.width - ovl.frame[2] - s.w;
            }
        }
        switch (self.align_v) {
            .centered => {
                y_a = (ovl.height - ovl.title.font_size - s.h) * 0.5 + ovl.ll_y + ovl.title.font_size;
            },
            .bottom => {
                y_a = ovl.ll_y + ovl.height - ovl.frame[3] - s.h;
            },
            .top => {
                y_a = ovl.ll_y + ovl.title.font_size + ovl.frame[1];
            }
        }
        try fnt.renderText(self.text, x_a, y_a);
    }
};

pub const ParamOverlay = struct {
    width: f32 = 100.0,
    height: f32 = 100.0,
    resize_mode: OverlayResizeMode = .auto,
    is_centered: bool = true,
    is_enabled: bool = true,
    ll_x: f32 = 0.0,
    ll_y: f32 = 0.0,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    title: Title = .{},
    frame: [4]f32 = .{10.0, 10.0, 10.0, 10.0},
    widget: ?*anyopaque = null,
    widget_type: WidgetType = .none,
};

pub fn addOverlay(name: []const u8, overlay: ParamOverlay) !void {
    try overlays.put(name, overlay);
}

pub fn addTextWidget(name_ol: []const u8, name_tw: []const u8, tw: TextWidget) !void {
    try text_widgets.put(name_tw, tw);
    const ol = overlays.getPtr(name_ol) orelse {
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
    text_widgets.deinit();

    const leaked = gpa.deinit();
    if (leaked) std.log.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn getOverlay(name: []const u8) GuiError!*ParamOverlay {
    return overlays.getPtr(name) orelse {
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

pub fn moveOverlay(x: f32, y: f32) void {
    const ovl = overlays.getPtr("fnt_ovl").?;
    ovl.ll_x += x;// * 0.01;
    ovl.ll_y += y;// * 0.01;
}

pub fn drawCursor(x: f32, y: f32) void {
    const cursor_size = 15;
    const cursor_gap_center = 5;
    const cursor_thickness = 3;
    if (is_cursor_visible) {
        gfx_impl.setColor(0.2, 1.0, 0.2, 0.5);
        gfx_impl.setLineWidth(cursor_thickness);
        gfx_impl.addImmediateLine(x-cursor_size, y, x-cursor_gap_center, y);
        gfx_impl.addImmediateLine(x+cursor_gap_center, y, x+cursor_size, y);
        gfx_impl.addImmediateLine(x, y-cursor_size, x, y-cursor_gap_center);
        gfx_impl.addImmediateLine(x, y+cursor_gap_center, x, y+cursor_size);
    }
}

pub fn drawOverlay(prm: *ParamOverlay) !void {
    const win_w = @intToFloat(f32, gfx_impl.getWindowWidth());
    const win_h = @intToFloat(f32, gfx_impl.getWindowHeight());

    if (prm.is_centered) {
        prm.ll_x = (win_w-prm.width) * 0.5;
        prm.ll_y = (win_h-prm.height) * 0.5;
    }

    gfx_impl.setColor(prm.col[0], prm.col[1], prm.col[2], prm.col[3]);
    gfx_impl.addImmediateQuad(prm.ll_x, prm.ll_y, prm.ll_x+prm.width, prm.ll_y+prm.height);

    if (prm.title.is_enabled) {
        try fnt.setFont(prm.title.font_name, prm.title.font_size);
        var title_x = prm.ll_x;
        switch (prm.title.alignment) {
            .centered => {
                const s = try fnt.getTextSize(prm.title.text);
                title_x = prm.ll_x + (prm.width-s.w) * 0.5;
            },
            .left => {
                title_x += prm.title.frame;
            },
            .right => {
                const s = try fnt.getTextSize(prm.title.text);
                title_x = prm.ll_x + prm.width - s.w - prm.title.frame;
            }
        }
        gfx_impl.setColor(prm.title.col[0], prm.title.col[1], prm.title.col[2], prm.title.col[3]);
        try fnt.renderText(prm.title.text, title_x, prm.ll_y);

        if (prm.title.is_separator_enabled) {
            gfx_impl.setLineWidth(prm.title.separator_thickness);
            gfx_impl.addImmediateLine(prm.ll_x + prm.title.frame, prm.ll_y + prm.title.font_size,
                                      prm.ll_x + prm.width - prm.title.frame, prm.ll_y + prm.title.font_size);
        }
    }

    if (prm.widget_type == .text and prm.widget != null) {
        const tw = @ptrCast(?*TextWidget, @alignCast(@alignOf(TextWidget), prm.widget)) orelse {
            gui_log.err("Unable to access widget for drawing", .{});
            return error.GuiWidgetCastFailed;
        };
        try fnt.setFont(tw.font_name, tw.font_size);
        gfx_impl.setColor(tw.col[0], tw.col[1], tw.col[2], tw.col[3]);
        try tw.draw();
    }
}

pub fn processOverlays() !void {
    var iter = overlays.iterator();

    while (iter.next()) |v| {
        if (v.value_ptr.is_enabled) try drawOverlay(v.value_ptr);
    }
}

pub inline fn hideCursor() void {
    is_cursor_visible = false;
}

pub inline fn showCursor() void {
    is_cursor_visible = true;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

/// Font manager logging scope
const gui_log = std.log.scoped(.fnt);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){}
          else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var is_cursor_visible: bool = false;

const WidgetType = enum {
    none,
    text,
};

var overlays = std.StringHashMap(ParamOverlay).init(allocator);
var text_widgets = std.StringHashMap(TextWidget).init(allocator);

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "gui: add widget (failure)" {
    const w = TextWidget{};
    const actual = addTextWidget("non_existing_overlay", "widget", w);
    const expected = GuiError.GuiUnknownOverlay;
    try std.testing.expectError(expected, actual);
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
    const ovl = ParamOverlay{};
    try addOverlay("valid_overlay", ovl);
}

test "gui: add text widget" {
    const w = TextWidget{};
    try addTextWidget("valid_overlay", "valid_widget", w);
}

test "gui: draw text widget (failure)" {
    var w = TextWidget{};
    const actual = w.draw();
    const expected = GuiError.GuiWidgetNoOverlay;
    try std.testing.expectError(expected, actual);
}
