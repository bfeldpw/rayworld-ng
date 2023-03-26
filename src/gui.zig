const fnt = @import("font_manager.zig");
const gfx_impl = @import("gfx_impl.zig");

pub const Title = struct {
    text: []const u8 = "Title",
    font_name: []const u8 = "anka",
    font_size: f32 = 32,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    is_centered: bool = true,
    is_enabled: bool = true,
};

pub const ParamOverlay = struct {
    width: f32 = 100.0,
    height: f32 = 100.0,
    is_centered: bool = true,
    ul_x: f32 = 0.0,
    ul_y: f32 = 0.0,
    col: [4]f32 = .{1.0, 1.0, 1.0, 1.0},
    title: Title,
};

pub fn drawOverlay(prm: ParamOverlay) !void {
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
        if (prm.title.is_centered) {
            const s = fnt.getTextSize(prm.title.text);
            ul_x = ul_x + (prm.width-s.w) * 0.5;
        }
        gfx_impl.setColor(prm.title.col[0], prm.title.col[1], prm.title.col[2], prm.title.col[3]);
        try fnt.renderText(prm.title.text, ul_x, ul_y);
    }
}
