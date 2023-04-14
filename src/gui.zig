const std = @import("std");
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx_impl = @import("gfx_impl.zig");

const presets = std.StringHashMap(ParamOverlay).init(allocator);

pub const Title = struct {
    text: []const u8 = "Title",
    font_name: []const u8 = "anka_b",
    font_size: f32 = 32,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    is_centered: bool = true,
    is_enabled: bool = true,
};

pub const TextWidget = struct {
    overlay: ParamOverlay,
    text: []const u8 = undefined,
    font_name: []const u8 = "anka_r",
    font_size: f32 = 32,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    frame: [2]f32 = .{10.0, 32.0},

    fn draw(self: *TextWidget, x: f32, y: f32) !void {
        try fnt.renderText(self.text, x + self.frame[0], y + self.frame[1]);
    }

};

pub const ParamOverlay = struct {
    width: f32 = 100.0,
    height: f32 = 100.0,
    is_centered: bool = true,
    ul_x: f32 = 0.0,
    ul_y: f32 = 0.0,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    title: Title,
    overlay_type: OverlayType = .none,
};

pub fn drawOverlay(prm: *ParamOverlay) !void {
    const win_w = @intToFloat(f32, gfx_impl.getWindowWidth());
    const win_h = @intToFloat(f32, gfx_impl.getWindowHeight());

    var ul_x: f32 = prm.ul_x;
    var ul_y: f32 = prm.ul_y;
    if (prm.is_centered) {
        ul_x = (win_w-prm.width) * 0.5;
        ul_y = (win_h-prm.height) * 0.5;
    }

    gfx_impl.setColor(prm.col[0], prm.col[1], prm.col[2], prm.col[3]);
    gfx_impl.addImmediateQuad(ul_x, ul_y, ul_x+prm.width, ul_y+prm.height);

    if (prm.title.is_enabled) {
        try fnt.setFont(prm.title.font_name, prm.title.font_size);
        var title_x = ul_x;
        if (prm.title.is_centered) {
            const s = fnt.getTextSize(prm.title.text);
            title_x = ul_x + (prm.width-s.w) * 0.5;
        }
        gfx_impl.setColor(prm.title.col[0], prm.title.col[1], prm.title.col[2], prm.title.col[3]);
        try fnt.renderText(prm.title.text, title_x, ul_y);
    }

    if (prm.overlay_type == .text) {
        const tw = @fieldParentPtr(TextWidget, "overlay", prm);
        try fnt.setFont(tw.font_name, tw.font_size);
        gfx_impl.setColor(tw.col[0], tw.col[1], tw.col[2], tw.col[3]);
        try tw.draw(ul_x, ul_y);
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

/// Font manager logging scope
const gui_log = std.log.scoped(.fnt);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){}
          else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const OverlayType = enum {
    none,
    text,
};
