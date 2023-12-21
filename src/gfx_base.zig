const std = @import("std");
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");

//-----------------------------------------------------------------------------//
//   Error Sets / Enums
//-----------------------------------------------------------------------------//

pub const AttributeMode = enum {
    None,
    Pxy,
    PxyCrgba,
    PxyCrgbaTuv,
    PxyCrgbaH,
    PxyCrgbaTuvH,
    PxyTuv
};


//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    // vao = try gfx_core.genVAO();
    var data_buf = std.ArrayList(f32).init(allocator);
    try data_buf.ensureTotalCapacity(batch_size);

    const buf_base = buffer_type{
        .data = data_buf,
        .vbo = try gfx_core.genBuffer(),
        .size = batch_size
    };
    try bufs.append(buf_base);
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, bufs.items[0].vbo, batch_size, .Dynamic);

    shader_program_pxy_crgba_f32 = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "pxy_crgba_f32_base.vert",
        cfg.gfx.shader_dir ++ "base.frag");
    shader_program_pxy_cuni_f32 = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "pxy_f32_base.vert",
        cfg.gfx.shader_dir ++ "pxy_cuni_f32.frag");
    shader_program_pxy_tuv_cuni_f32 = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "pxy_tuv_f32_base.vert",
        cfg.gfx.shader_dir ++ "pxy_tuv_cuni_f32_base.frag");
    shader_program_pxy_tuv_cuni_f32_font = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "pxy_tuv_f32_base.vert",
        cfg.gfx.shader_dir ++ "pxy_tuv_cuni_f32_font.frag");

    const o_w = @as(f32, @floatFromInt(gfx_core.getWindowWidth()/2));
    const o_h = @as(f32, @floatFromInt(gfx_core.getWindowHeight()/2));
    const w_r = 1.0 / o_w;
    const h_r = 1.0 / o_h;
    try gfx_core.setUniform4f(shader_program_pxy_crgba_f32, "t", w_r, h_r, o_w, o_h);
    try gfx_core.setUniform4f(shader_program_pxy_cuni_f32, "t", w_r, h_r, o_w, o_h);
    try gfx_core.setUniform4f(shader_program_pxy_cuni_f32, "u_col", 1.0, 1.0, 1.0, 1.0);
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32, "t", w_r, h_r, o_w, o_h);
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32, "u_col", 1.0, 1.0, 1.0, 1.0);
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32_font, "t", w_r, h_r, o_w, o_h);
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32_font, "u_col", 1.0, 1.0, 1.0, 1.0);

    try gfx_core.addWindowResizeCallback(&handleWindowResize);
}

pub fn deinit() void {
    for (bufs.items) |v| v.data.deinit();
    bufs.deinit();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn addBuffer(n: u32) !u32 {
    const buf_id = bufs.items.len;
    var data_buf = std.ArrayList(f32).init(allocator);
    try data_buf.ensureTotalCapacity(n);

    const buf = buffer_type{
        .data = data_buf,
        .vbo = try gfx_core.genBuffer(),
        .size = n
    };
    try bufs.append(buf);
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, bufs.items[buf_id].vbo, n, .Dynamic);
    return @intCast(buf_id);
}

pub fn addVertexData(buf_id: u32, data: []f32) !void {
    try bufs.items[buf_id].data.appendSlice(data);
}

pub fn getBufferToAddVertexData(buf_id: u32, n: u32) ![]f32 {
    return try bufs.items[buf_id].data.addManyAsSlice(n);
}

pub fn addCircle(buf_id: u32, c_x: f32, c_y: f32, ra: f32,
                 r: f32, g: f32, b: f32, a: f32) !void {
    const nr_of_segments = 100.0;

    var angle: f32 = 0.0;
    const inc = 2.0 * std.math.pi / nr_of_segments;
    while (angle < 2.0 * std.math.pi) : (angle += inc) {
        try bufs.items[buf_id].data.append(ra * @cos(angle) + c_x);
        try bufs.items[buf_id].data.append(ra * @sin(angle) + c_y);
        try bufs.items[buf_id].data.append(r);
        try bufs.items[buf_id].data.append(g);
        try bufs.items[buf_id].data.append(b);
        try bufs.items[buf_id].data.append(a);
    }
}

pub fn renderBatch(buf_id: u32, sp: u32, m: AttributeMode, prim: gfx_core.PrimitiveMode) !void {
    try gfx_core.useShaderProgram(sp);
    // try gfx_core.bindVAO(vao);
    if (bufs.items[buf_id].data.items.len > bufs.items[buf_id].size) {

        const s: u32 = @intCast(bufs.items[buf_id].data.items.len);

        try gfx_core.bindVBOAndBufferData(bufs.items[buf_id].vbo, s,
                                          bufs.items[buf_id].data.items, .Dynamic);
        bufs.items[buf_id].size = s;
        log_gfx.debug("Resizing vbo {}, n = {}", .{buf_id, s});

    } else {

        try gfx_core.bindVBOAndBufferSubData(f32, 0, bufs.items[buf_id].vbo,
                                             @intCast(bufs.items[buf_id].data.items.len),
                                             bufs.items[buf_id].data.items);

    }
    const s = try setVertexAttributeMode(m);

    try gfx_core.drawArrays(prim, 0, @intCast(bufs.items[buf_id].data.items.len / s));
    bufs.items[buf_id].data.clearRetainingCapacity();
}

pub fn renderBatchPxyCrgbaF32(buf_id: u32, prim: gfx_core.PrimitiveMode) !void {
    try renderBatch(buf_id, shader_program_pxy_crgba_f32, .PxyCrgba, prim);
}

pub fn renderBatchPxyCuniF32(buf_id: u32, prim: gfx_core.PrimitiveMode,
                             r: f32, g: f32, b: f32, a: f32) !void {

    try gfx_core.setUniform4f(shader_program_pxy_cuni_f32, "u_col", r, g, b, a);
    try renderBatch(buf_id, shader_program_pxy_cuni_f32, .Pxy, prim);
}

pub fn renderBatchPxyTuvCuniF32(buf_id: u32, prim: gfx_core.PrimitiveMode,
                                r: f32, g: f32, b: f32, a: f32) !void {
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32, "u_col", r, g, b, a);
    try renderBatch(buf_id, shader_program_pxy_tuv_cuni_f32, .PxyTuv, prim);
}

pub fn renderBatchPxyTuvCuniF32Font(buf_id: u32, prim: gfx_core.PrimitiveMode,
                                    r: f32, g: f32, b: f32, a: f32) !void {
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32_font, "u_col", r, g, b, a);
    try renderBatch(buf_id, shader_program_pxy_tuv_cuni_f32_font, .PxyTuv, prim);
}

pub fn setColorPxyCuniF32(r: f32, g: f32, b: f32, a: f32) !void {
    try gfx_core.setUniform4f(shader_program_pxy_cuni_f32, "u_col", r, g, b, a);
}

pub fn setColorPxyTuvCuniF32(r: f32, g: f32, b: f32, a: f32) !void {
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32, "u_col", r, g, b, a);
}

pub fn setColorPxyTuvCuniF32Font(r: f32, g: f32, b: f32, a: f32) !void {
    try gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32_font, "u_col", r, g, b, a);
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
        .PxyTuv => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.enableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(1);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 4, 0);
            try gfx_core.setupVertexAttributesFloat(2, 2, 4, 2);
            len = 4;
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

const buffer_type = struct{
    size: u32,
    vbo: u32,
    data: std.ArrayList(f32),
};
var bufs = std.ArrayList(buffer_type).init(allocator);
var batch_size: u32 = 2_100_000; // 100 000 textured triangles (100 000 * (3 * (2 vert-coords + 4 colors + 2 tex-coords)

var shader_program_pxy_crgba_f32: u32 = 0;
var shader_program_pxy_cuni_f32: u32 = 0;
var shader_program_pxy_tuv_cuni_f32: u32 = 0;
var shader_program_pxy_tuv_cuni_f32_font: u32 = 0;

fn handleWindowResize(w: u32, h: u32) void {
    // Adjust projection for vertex shader
    // (simple ortho projection, therefore, no explicit matrix)
    const o_w = @as(f32, @floatFromInt(w/2));
    const o_h = @as(f32, @floatFromInt(h/2));
    const w_r = 1.0 / o_w;
    const h_r = 1.0 / o_h;
    updateProjection(shader_program_pxy_crgba_f32, w_r, h_r, o_w, o_h);
    updateProjection(shader_program_pxy_cuni_f32, w_r, h_r, o_w, o_h);
    updateProjection(shader_program_pxy_tuv_cuni_f32, w_r, h_r, o_w, o_h);
    updateProjection(shader_program_pxy_tuv_cuni_f32_font, w_r, h_r, o_w, o_h);

    log_gfx.debug("Window resize callback triggered, w = {}, h = {}", .{w, h});
}

pub fn updateProjection(sp: u32, w_r: f32, h_r: f32, o_w: f32, o_h: f32) void {
    gfx_core.setUniform4f(sp, "t", w_r, h_r, o_w, o_h) catch |e| {
        log_gfx.err("{}", .{e});
    };
}

pub fn updateProjectionPxyTuvCuniF32(w_r: f32, h_r: f32, o_w: f32, o_h: f32) void {
    gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32, "t", w_r, h_r, o_w, o_h) catch |e| {
        log_gfx.err("{}", .{e});
    };
}

pub fn updateProjectionPxyTuvCuniF32Font(w_r: f32, h_r: f32, o_w: f32, o_h: f32) void {
    gfx_core.setUniform4f(shader_program_pxy_tuv_cuni_f32_font, "t", w_r, h_r, o_w, o_h) catch |e| {
        log_gfx.err("{}", .{e});
    };
}
