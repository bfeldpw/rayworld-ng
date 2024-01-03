const gfx_core = @import("gfx_core.zig");
const gfx_base = @import("gfx_base.zig");

//-----------------------------------------------------------------------------//
//   Init / Deinit
//-----------------------------------------------------------------------------//

var buf_id: u32 = 0;
var is_initialised: bool = false;

/// Everything that needs to be initialised on graphics engine side
pub fn init() !void {
    const nr_of_quads = 10000;
    buf_id = try gfx_base.addBuffer(24 * nr_of_quads, .PxyTuvCuniF32Font);

    is_initialised = true;
}

//-----------------------------------------------------------------------------//
//   Texture handling
//-----------------------------------------------------------------------------//

/// Bind a texture
pub inline fn bindTexture(id: u32) !void {
    try gfx_core.bindTexture(id);
}

/// Create a texture with given size, data, and texture id (from genTexture)
pub inline fn createTextureAlpha(w: u32, h: u32, data: []u8, id: u32) !void {
    try gfx_core.createTextureAlpha(w, h, data, id);
}

/// Delete a texture with given id
pub inline fn deleteTexture(id: u32) !void {
    try gfx_core.deleteTexture(id);
}

/// Generate a new texture object
pub inline fn genTexture() !u32 {
    return try gfx_core.genTexture();
}

//-----------------------------------------------------------------------------//
//   Rendering
//-----------------------------------------------------------------------------//

/// Add a textured quad (single character) to render pipeline
pub fn addQuadTextured(x0: f32, y0: f32, x1: f32, y1: f32,
                       u: f32, v: f32, uu: f32, vv: f32) !void {

    const data = try gfx_base.getBufferToAddVertexData(buf_id, 24);
    const data_p = data.ptr;

    data_p[ 0] = x0;
    data_p[ 1] = y0;
    data_p[ 2] = u;
    data_p[ 3] = v;

    data_p[ 4] = x1;
    data_p[ 5] = y1;
    data_p[ 6] = uu;
    data_p[ 7] = vv;

    data_p[ 8] = x0;
    data_p[ 9] = y1;
    data_p[10] = u;
    data_p[11] = vv;

    data_p[12] = x1;
    data_p[13] = y1;
    data_p[14] = uu;
    data_p[15] = vv;

    data_p[16] = x0;
    data_p[17] = y0;
    data_p[18] = u;
    data_p[19] = v;

    data_p[20] = x1;
    data_p[21] = y0;
    data_p[22] = uu;
    data_p[23] = v;
}

/// Render textured quads with given color
/// Take care of setting data format such as
/// vertex attributes, setting up shader etc...
pub fn renderBatch(r: f32, g: f32, b: f32, a: f32) !void {
    try gfx_base.setColor(.PxyTuvCuniF32Font, r, g, b, a);
    try gfx_base.renderBatch(buf_id, .Triangles, .Update);
}
