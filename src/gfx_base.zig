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
    var vbo_buf_base = std.ArrayList(f32).init(allocator);
    try vbo_buf_base.ensureTotalCapacity(batch_size);
    try vbo_bufs.append(vbo_buf_base);
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, vbo, batch_size, .Dynamic);
}

pub fn deinit() void {
    for (vbo_bufs.items) |v| v.deinit();
    vbo_bufs.deinit();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn addBuffer(n: u32) !u32 {
    const buf_id = vbo_bufs.items.len;
    var vbo_buf = std.ArrayList(f32).init(allocator);
    try vbo_buf.ensureTotalCapacity(n);
    try vbo_bufs.append(vbo_buf);
    return @intCast(buf_id);
}

pub fn addVertexData(buf_id: u32, data: []f32) !void {
    try vbo_bufs.items[buf_id].appendSlice(data);
}

pub fn addCircle(buf_id: u32, c_x: f32, c_y: f32, ra: f32,
                 r: f32, g: f32, b: f32, a: f32) !void {
    const nr_of_segments = 100.0;

    var angle: f32 = 0.0;
    const inc = 2.0 * std.math.pi / nr_of_segments;
    while (angle < 2.0 * std.math.pi) : (angle += inc) {
        try vbo_bufs.items[buf_id].append(ra * @cos(angle) + c_x);
        try vbo_bufs.items[buf_id].append(ra * @sin(angle) + c_y);
        try vbo_bufs.items[buf_id].append(r);
        try vbo_bufs.items[buf_id].append(g);
        try vbo_bufs.items[buf_id].append(b);
        try vbo_bufs.items[buf_id].append(a);
    }
}

pub fn renderBatch(buf_id: u32, sp: u32, m: AttributeMode, prim: gfx_core.PrimitiveMode) !void {
    try gfx_core.useShaderProgram(sp);
    // try gfx_core.bindVAO(vao);
    try gfx_core.bindVBOAndBufferSubData(f32, 0, vbo, @intCast(vbo_bufs.items[buf_id].items.len), vbo_bufs.items[buf_id].items);
    const s = try setVertexAttributeMode(m);

    try gfx_core.drawArrays(prim, 0, @intCast(vbo_bufs.items[buf_id].items.len / s));
    vbo_bufs.items[buf_id].clearRetainingCapacity();
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
var vbo_bufs = std.ArrayList(std.ArrayList(f32)).init(allocator);
// var vao: u32 = 0;
var vbo: u32 = 0;
