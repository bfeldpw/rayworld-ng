const gfx_core = @import("gfx_core.zig");

pub inline fn bindTexture(id: u32) !void {
    try gfx_core.bindTexture(id);
}

pub inline fn createTextureAlpha(w: u32, h: u32, data: []u8, id: u32) !void {
    try gfx_core.createTextureAlpha(w, h, data, id);
}

pub inline fn deleteTexture(id: u32) !void {
    try gfx_core.deleteTexture(id);
}

pub inline fn genTexture() !u32 {
    return try gfx_core.genTexture();
}
