const std = @import("std");
const builtin = @import("builtin");
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");

//-----------------------------------------------------------------------------//
//   Error Sets / Enums
//-----------------------------------------------------------------------------//

pub const RenderMode = enum {
    None,
    PxyCuniF32,
    PxyCrgbaF32,
    PxyCrgbaTuv,
    PxyCrgbaH,
    PxyCrgbaTuvH,
    PxyTuvCuniF32,
    PxyTuvCuniF32Font
};

pub const BufferedDataHandling = enum {
    Keep,
    Update
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    shader_program_pxy_crgba_f32 = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "pxy_crgba_f32_base.vert",
        cfg.gfx.shader_dir ++ "pxy_crgba_f32_base.frag");
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
    cleanupGL() catch |err| {
        log_gfx.err("Couldn't clean up GL successfully: {}", .{err});
    };
    for (bufs.items) |v| v.data.deinit();
    bufs.deinit();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

fn cleanupGL() !void {
    try gfx_core.deleteShaderProgram(shader_program_pxy_crgba_f32);
    try gfx_core.deleteShaderProgram(shader_program_pxy_cuni_f32);
    try gfx_core.deleteShaderProgram(shader_program_pxy_tuv_cuni_f32);
    try gfx_core.deleteShaderProgram(shader_program_pxy_tuv_cuni_f32_font);
    for (bufs.items) |v| {
        try gfx_core.deleteBuffer(v.vbo_0);
        try gfx_core.deleteBuffer(v.vbo_1);
    }
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn addBuffer(n: u32, comptime rm: RenderMode) !u32 {
    const buf_id = bufs.items.len;
    var data_buf = std.ArrayList(f32).init(allocator);
    try data_buf.ensureTotalCapacity(n);

    const buf = buffer_type{
        .data = data_buf,
        .vao = try gfx_core.genVAO(),
        .vbo_0 = try gfx_core.genBuffer(),
        .vbo_1 = try gfx_core.genBuffer(),
        .size = n,
        .render_mode = rm,
        .attr_size = 4,
        .update = false
    };
    try bufs.append(buf);
    try gfx_core.bindVAO(buf.vao);
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, bufs.items[buf_id].vbo_0, n, .Dynamic);
    _ = try setVertexAttributes(buf.render_mode);
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, bufs.items[buf_id].vbo_1, n, .Dynamic);
    bufs.items[buf_id].attr_size = try setVertexAttributes(buf.render_mode);

    if (builtin.mode == .Debug) {
        try gfx_core.unbindVAO();
    }
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


pub fn renderBatch(buf_id: u32, prim: gfx_core.PrimitiveMode,
                   bdh: BufferedDataHandling) !void {
    const buf = &bufs.items[buf_id];
    try gfx_core.useShaderProgram(getShaderProgramFromRenderMode(buf.render_mode));
    if (bdh == .Update or !buf.update) {
        if (buf.data.items.len > buf.size) {

            const l: u32 = @intCast(buf.data.items.len);

            try gfx_core.bindVBOAndBufferData(buf.vbo_0, l,
                                              buf.data.items, .Dynamic);
            buf.size = l;
            log_gfx.debug("Resizing vbo {}, n = {}", .{buf_id, l});

        } else {
            try gfx_core.bindVBOAndBufferSubData(f32, 0, buf.vbo_0,
                                                @intCast(buf.data.items.len),
                                                buf.data.items);
        }
        if (!buf.update) {
            std.mem.swap(u32, &buf.vbo_0, &buf.vbo_1);
        }
        if (bdh == .Keep) {
            buf.update = true;
        }
    }
    try gfx_core.bindVAO(buf.vao);
    try gfx_core.bindVBO(buf.vbo_1);
    // const s = buf.attr_size;
    const s = try setVertexAttributes(buf.render_mode);
    try gfx_core.drawArrays(prim, 0, @intCast(buf.data.items.len / s));

    if (bdh == .Update) {
        bufs.items[buf_id].data.clearRetainingCapacity();
        std.mem.swap(u32, &buf.vbo_0, &buf.vbo_1);
        buf.update = false;
    }

    if (builtin.mode == .Debug) {
        try gfx_core.unbindVAO();
    }
}

fn getShaderProgramFromRenderMode(rm: RenderMode) u32 {
    var sp: u32 = 0;
    switch (rm) {
        .PxyCuniF32 => sp = shader_program_pxy_cuni_f32,
        .PxyCrgbaF32 => sp = shader_program_pxy_crgba_f32,
        .PxyTuvCuniF32 => sp = shader_program_pxy_tuv_cuni_f32,
        .PxyTuvCuniF32Font => sp = shader_program_pxy_tuv_cuni_f32_font,
        else => { log_gfx.warn("Shader mapping for render mode {} not implemented", .{rm}); }
    }
    return sp;
}

pub fn setColor(comptime rm: RenderMode, r: f32, g: f32, b: f32, a: f32) !void {
    comptime {
        if (rm != .PxyCuniF32 and
            rm != .PxyTuvCuniF32 and
            rm != .PxyTuvCuniF32Font) @compileError("Not possible to set color for given rendermode");
    }
    try gfx_core.setUniform4f(getShaderProgramFromRenderMode(rm), "u_col", r, g, b, a);
}

//-----------------------------------------------------------------------------//
//   Predefined vertex attribute modes
//-----------------------------------------------------------------------------//

pub fn setVertexAttributes(rm: RenderMode) !u32 {
    var len: u32 = 0;
    switch (rm) {
        .PxyCuniF32 => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.disableVertexAttributes(1);
            try gfx_core.disableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 2, 0);
            len = 2;
        },
        .PxyCrgbaF32 => {
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
        .PxyTuvCuniF32,
        .PxyTuvCuniF32Font => {
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
    vao: u32,
    vbo_0: u32,
    vbo_1: u32,
    data: std.ArrayList(f32),
    render_mode: RenderMode,
    attr_size: u32,
    update: bool
};
var bufs = std.ArrayList(buffer_type).init(allocator);
var batch_size: u32 = 2_100_000; // 100 000 textured triangles (100 000 * (3 * (2 vert-coords + 4 colors + 2 tex-coords)
// var vao: u32 = 0;

var shader_program_pxy_crgba_f32: u32 = 0;
var shader_program_pxy_cuni_f32: u32 = 0;
var shader_program_pxy_tuv_cuni_f32: u32 = 0;
var shader_program_pxy_tuv_cuni_f32_font: u32 = 0;

fn handleWindowResize(w: u32, h: u32) void {
    // Adjust projection for vertex shader
    // (simple ortho projection, therefore, no explicit matrix)

    // projectOrtho(shader_program_pxy_crgba_f32, 0, @floatFromInt(w - 1), @floatFromInt(h - 1), 0);
    // projectOrtho(shader_program_pxy_cuni_f32, 0, @floatFromInt(w - 1), @floatFromInt(h - 1), 0);
    // projectOrtho(shader_program_pxy_tuv_cuni_f32, 0, @floatFromInt(w - 1), @floatFromInt(h - 1), 0);
    // projectOrtho(shader_program_pxy_tuv_cuni_f32_font, 0, @floatFromInt(w - 1), @floatFromInt(h - 1), 0);

    log_gfx.debug("Window resize callback triggered, w = {}, h = {}", .{w, h});
}

pub fn updateProjection(rm: RenderMode, l: f32, r: f32, b: f32, t: f32) void {
    projectOrtho(getShaderProgramFromRenderMode(rm), l, r, b, t);
}

pub fn projectOrtho(sp: u32, l: f32, r: f32, b: f32, t: f32) void {
    const x = 2.0 / (r - l);
    const y = 2.0 / (t - b);
    const x_o = - (r + l) / (r - l);
    const y_o = - (t + b) / (t - b);

    gfx_core.setUniform4f(sp, "t", x, y, x_o, y_o) catch |err| {
        log_gfx.err("{}", .{err});
    };
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "init_glx_base" {
    try gfx_core.init();
    try init();
    try std.testing.expect(bufs.items.len == 1);
    try std.testing.expect(bufs.items[0].data.items.len == 0);
    try std.testing.expect(bufs.items[0].size == batch_size);
    try std.testing.expect(bufs.items[0].vbo_0 > 0);
    try std.testing.expect(bufs.items[0].vbo_1 > 0);
}

test "add_buffer" {
    const buf_id = try addBuffer(1024);
    try std.testing.expect(bufs.items.len == 2);
    try std.testing.expect(bufs.items[buf_id].data.items.len == 0);
    try std.testing.expect(bufs.items[buf_id].size == 1024);
    try std.testing.expect(bufs.items[buf_id].vbo_0 > 0);
    try std.testing.expect(bufs.items[buf_id].vbo_1 > 0);
}

test "add_circle" {
    const buf_id = try addBuffer(600);
    try std.testing.expect(bufs.items.len == 3);
    try std.testing.expect(bufs.items[buf_id].data.items.len == 0);
    try std.testing.expect(bufs.items[buf_id].size == 600);
    try std.testing.expect(bufs.items[buf_id].vbo_0 > 0);
    try std.testing.expect(bufs.items[buf_id].vbo_1 > 0);

    try addCircle(buf_id, 0, 0, 1.0, 1, 1, 1, 1);
    try std.testing.expect(bufs.items[buf_id].data.items.len == 600);
}
