// This helper consists of a few specialised calls to a graphics
// API that has to be implemented by the user.

/// This is the graphics backend
const gfx = @import("graphics.zig");

/// Add a quad to a batch of quads. Handling of batches is
/// implementation specific, might also internally draw
/// immediately. However, this function is typically called
/// where a lot of quads are drawn, so draw calls might be
/// relevant.
pub inline fn addBatchQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    gfx.addQuad(x0, y0, x1, y1);
}

/// Add a quad to a batch of textured quads. Handling of batches
/// is implementation specific, might also internally draw
/// immediately. However, this function is typically called
/// where a lot of quads are drawn, so draw calls might be
/// relevant.
pub inline fn addBatchQuadTextured(x0: f32, y0: f32, x1: f32, y1: f32,
                                   u_0: f32, v0: f32, u_1: f32, v1: f32) void {
    gfx.addQuadTextured(x0, y0, x1, y1, u_0, v0, u_1, v1);
}

/// Immediately draw a line. Internal handling is implementation
/// specific and may also happen within a batch, though this is
/// typically called for a few single line
pub inline fn addImmediateLine(x0: f32, y0: f32, x1: f32, y1: f32) void {
    gfx.drawLine(x0, y0, x1, y1);
}

/// Immediately draw a quad. Internal handling is implementation
/// specific and may also happen within a batch, though this is
/// typically called for a few single quads
pub inline fn addImmediateQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    gfx.drawQuad(x0, y0, x1, y1);
}

/// Immediately draw a textured quad. Internal handling is implementation
/// specific and may also happen within a batch, though this is
/// typically called for a few single quads
pub inline fn addImmediateQuadTextured(x0: f32, y0: f32, x1: f32, y1: f32,
                                       u_0: f32, v0: f32, u_1: f32, v1: f32) void {
    gfx.drawQuadTextured(x0, y0, x1, y1, u_0, v0, u_1, v1);
}

/// Begin with a batch of quads. This function might be relevant for
/// e.g. immediate mode of OpenGL, but may as well be left empty if
/// batches are implemented differently, using core profile, VBOs
/// or other methods
pub inline fn beginBatchQuads() void {
    gfx.startBatchQuads();
}

/// Begin with a batch of textured quads. This function might be relevant
/// for e.g. immediate mode of OpenGL, but may as well be left empty if
/// batches are implemented differently, using core profile, VBOs
/// or other methods
pub inline fn beginBatchQuadsTextured() void {
    gfx.startBatchQuadsTextured();
}

pub inline fn bindTexture(tex_id: u32) void {
    gfx.bindTexture(tex_id);
}

/// End a batch call, see beginBatch-functions for a more detailed explanation
pub inline fn endBatch() void {
    gfx.endBatch();
}

/// Upload data in the data array as a texture with the given ID. Here,
/// the data is only one channel and to be interpreted as alpha. It is
/// mostly used for font rendering, where the background is interpreted
/// as alpha=0
pub inline fn createTextureAlpha(w: u32, h: u32, data: []u8, tex_id: u32) void {
    gfx.createTexture1C(w, h, data, tex_id);
}

/// Generate a new texture ID to upload data to
pub inline fn getNewTextureId() u32 {
    return gfx.getTextureId();
}

/// Height of the window with the graphical context
pub inline fn getWindowHeight() u64 {
    return gfx.getWindowHeight();
}

/// Width of the window with the graphical context
pub inline fn getWindowWidth() u64 {
    return gfx.getWindowWidth();
}

/// Release a texture with the given ID
pub inline fn releaseTexture(tex_id: u32) void {
    gfx.releaseTexture(tex_id);
}

/// Set the color (RGBA) for upcoming operations. If using VBAs/VBOs
/// for example, a helper functions and data might be implemented
/// to fill arrays
pub inline fn setColor(r: f32, g: f32, b: f32, a: f32) void {
    gfx.setColor4(r, g, b, a);
}

/// Set the width of lines drawn by the graphics engine
pub inline fn setLineWidth(w: f32) void {
    gfx.setLineWidth(w);
}
