// Remove "_template" from filename and implement functions to make the font
// manager work with your graphics engine

//-----------------------------------------------------------------------------//
//   Init / Deinit
//-----------------------------------------------------------------------------//

/// Everything that needs to be initialised on graphics engine side
pub fn init() !void {
}

//-----------------------------------------------------------------------------//
//   Texture handling
//-----------------------------------------------------------------------------//

/// Bind a texture
pub inline fn bindTexture(id: u32) !void {
    _ = id;
}

/// Create a texture with given size, data, and texture id (from genTexture)
pub inline fn createTextureAlpha(w: u32, h: u32, data: []u8, id: u32) !void {
    _ = w;
    _ = h;
    _ = data;
    _ = id;
}

/// Delete a texture with given id
pub inline fn deleteTexture(id: u32) !void {
    _ = id;
}

/// Generate a new texture object
pub inline fn genTexture() !u32 {
}

//-----------------------------------------------------------------------------//
//   Rendering
//-----------------------------------------------------------------------------//

/// Add a textured quad (single character) to render pipeline
pub fn addQuadTextured(x0: f32, y0: f32, x1: f32, y1: f32,
                       u: f32, v: f32, uu: f32, vv: f32) !void {
    _ = x0;
    _ = y0;
    _ = x1;
    _ = y1;
    _ = u;
    _ = v;
    _ = uu;
    _ = vv;
}

/// Render textured quads with given color
/// Take care of setting data format such as
/// vertex attributes, setting up shader etc...
pub fn renderBatch(r: f32, g: f32, b: f32, a: f32) !void {
    _ = r;
    _ = g;
    _ = b;
    _ = a;
}
