const gfx = @import("graphics.zig");

pub inline fn createQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    gfx.drawQuad(x0, y0, x1, y1);
}

pub inline fn createTextureAlpha(w: u32, h: u32, data: []u8, tex_id: u32) void {
    gfx.createTexture1C(w, h, data, tex_id);
}

pub inline fn getNewTextureId() u32 {
    return gfx.getTextureId();
}

pub inline fn getWindowHeight() u64 {
    return gfx.getWindowHeight();
}

pub inline fn getWindowWidth() u64 {
    return gfx.getWindowWidth();
}

pub inline fn releaseTexture(tex_id: u32) void {
    gfx.releaseTexture(tex_id);
}

pub inline fn setColor(r: f32, g: f32, b: f32, a: f32) void {
    gfx.setColor4(r, g, b, a);
}

pub inline fn setActiveTexture(tex_id: u32) void {
    gfx.setActiveTexture(tex_id);
}
