const std = @import("std");
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");

//-----------------------------------------------------------------------------//
//   Error Sets / Enums
//-----------------------------------------------------------------------------//

const AttributeMode = enum {
    None,
    Pxy,
    PxyCrgba,
    PxyCrgbaTuv,
    PxyCrgbaH,
    PxyCrgbaTuvH
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    // vao = try gfx_core.genVAO();
    vbo = try gfx_core.genBuffer();
    try vbo_buf.ensureTotalCapacity(batch_size);
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, vbo, batch_size, .Dynamic);
}

pub fn deinit() void {
    vbo_buf.deinit();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn addVertexPxyCrgba(x: f32, y: f32, r: f32, g: f32, b: f32, a: f32) !void {
    try vbo_buf.append(x);
    try vbo_buf.append(y);
    try vbo_buf.append(r);
    try vbo_buf.append(g);
    try vbo_buf.append(b);
    try vbo_buf.append(a);
}

pub fn renderBatch(sp: u32, m: AttributeMode, prim: gfx_core.PrimitiveMode) !void {
    try gfx_core.useShaderProgram(sp);
    // try gfx_core.bindVAO(vao);
    try gfx_core.bindVBOAndBufferSubData(f32, 0, vbo, @intCast(vbo_buf.items.len), vbo_buf.items);
    const s = try setVertexAttributeMode(m);

    try gfx_core.drawArrays(prim, 0, @intCast(vbo_buf.items.len / s));
    vbo_buf.clearRetainingCapacity();
}

//-----------------------------------------------------------------------------//
//   Predefined vertex attribute modes
//-----------------------------------------------------------------------------//

pub fn setVertexAttributeMode(m: AttributeMode) !u32 {
    var len: u32 = 0;
    switch (m) {
        .Pxy => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.disableVertexAttributes(1);
            try gfx_core.disableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 2, 0);
            len = 2;
        },
        .PxyCrgba => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.enableVertexAttributes(1);
            try gfx_core.disableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 6, 0);
            try gfx_core.setupVertexAttributesFloat(1, 4, 6, 2);
            len = 6;
        },
        .PxyCrgbaTuv => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.enableVertexAttributes(1);
            try gfx_core.enableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 8, 0);
            try gfx_core.setupVertexAttributesFloat(1, 4, 8, 2);
            try gfx_core.setupVertexAttributesFloat(2, 2, 8, 6);
            len = 8;
        },
        .PxyCrgbaTuvH => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.enableVertexAttributes(1);
            try gfx_core.enableVertexAttributes(2);
            try gfx_core.enableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 10, 0);
            try gfx_core.setupVertexAttributesFloat(1, 4, 10, 2);
            try gfx_core.setupVertexAttributesFloat(2, 2, 10, 6);
            try gfx_core.setupVertexAttributesFloat(3, 2, 10, 8);
            len = 10;
        },
        else => {}
    }
    return len;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//
const log_gfx = std.log.scoped(.gfx_base);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const batch_size = 2_100_000; // 100 000 textured triangles (100 000 * (3 * (2 vert-coords + 4 colors + 2 tex-coords)
var vbo_buf = std.ArrayList(f32).init(allocator);
// var vao: u32 = 0;
var vbo: u32 = 0;
