const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");
const stats = @import("stats.zig");

const builtin = @import("builtin");

//-----------------------------------------------------------------------------//
//   Error Sets / Enums
//-----------------------------------------------------------------------------//

const AttributeMode = enum {
    None,
    Pxy,
    PxyCrgba,
    PxyCrgbaH
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    vao_0 = try gfx_core.createVAO();
    ebo = try gfx_core.createBuffer();
    vbo_0 = try gfx_core.createBuffer();
    try initShaders();
    try gfx_core.addWindowResizeCallback(&handleWindowResize);

    var s: u32 = buf_size;
    if (buf_size_lines > s) s = buf_size_lines;
    try gfx_core.bindVBOAndReserveBuffer(.Array, vbo_0, s, .Dynamic);

    var ebo_buf = std.ArrayList(u32).init(allocator);
    try ebo_buf.ensureTotalCapacity(buf_size*6);
    var i: u32 = 0;
    while (i < buf_size) : (i += 1) {
        ebo_buf.appendAssumeCapacity(0 + 4 * i);
        ebo_buf.appendAssumeCapacity(1 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(3 + 4 * i);
        ebo_buf.appendAssumeCapacity(0 + 4 * i);
    }
    try gfx_core.bindEBOAndBufferData(ebo, buf_size*6, ebo_buf.items, .Static);
    ebo_buf.deinit();

    buf = try allocator.create(buf_type);
    i = 0;
    while (i < cfg.gfx.depth_levels_max) : (i += 1) {
        buf_n[i] = 0;
    }
    buf_lines = try allocator.create(buf_type_lines);
}

pub fn deinit() void {
    allocator.destroy(buf);
    allocator.destroy(buf_lines);

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

pub fn initShaders() !void {
    log_gfx.info("Processing shaders", .{});

    shader_program = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "base.vert",
        cfg.gfx.shader_dir ++ "base.frag");
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Fill render pipeline
//-----------------------------------------------------------------------------//

pub fn addLine(x0: f32, y0: f32, x1: f32, y1: f32, r: f32, g: f32, b: f32, a: f32) void {
    const i = buf_n_lines;
    buf_lines[i   ] = x0;
    buf_lines[i+1 ] = y0;
    buf_lines[i+2 ] = r;
    buf_lines[i+3 ] = g;
    buf_lines[i+4 ] = b;
    buf_lines[i+5 ] = a;
    buf_lines[i+6 ] = x1;
    buf_lines[i+7 ] = y1;
    buf_lines[i+8 ] = r;
    buf_lines[i+9 ] = g;
    buf_lines[i+10] = b;
    buf_lines[i+11] = a;
    buf_n_lines += 12;
}

pub fn addQuad(x0: f32, y0: f32, x1: f32, y1: f32, r: f32, g: f32, b: f32, a: f32, d0: u8) void {
    const i = buf_n[d0];
    const h = y1 - y0;
    buf[d0][i   ] = x0;
    buf[d0][i+1 ] = y0;
    buf[d0][i+2 ] = r;
    buf[d0][i+3 ] = g;
    buf[d0][i+4 ] = b;
    buf[d0][i+5 ] = a;
    buf[d0][i+6 ] = h;
    buf[d0][i+7 ] = x1;
    buf[d0][i+8 ] = y0;
    buf[d0][i+9 ] = r;
    buf[d0][i+10] = g;
    buf[d0][i+11] = b;
    buf[d0][i+12] = a;
    buf[d0][i+13] = h;
    buf[d0][i+14] = x1;
    buf[d0][i+15] = y1;
    buf[d0][i+16] = r;
    buf[d0][i+17] = g;
    buf[d0][i+18] = b;
    buf[d0][i+19] = a;
    buf[d0][i+20] = h;
    buf[d0][i+21] = x0;
    buf[d0][i+22] = y1;
    buf[d0][i+23] = r;
    buf[d0][i+24] = g;
    buf[d0][i+25] = b;
    buf[d0][i+26] = a;
    buf[d0][i+27] = h;
    buf_n[d0] += 28;
}

// pub fn addVerticalQuad(x0: f32, x1: f32, y0: f32, y1: f32, r: f32, g: f32, b: f32, a: f32, d0: u8) void {
//     _ = y1;
//     _ = y0;
//     _ = x1;
//     _ = x0;
//     _ = d0;
//     _ = a;
//     _ = b;
//     _ = g;
//     _ = r;
//     log_gfx.debug("Test", .{});
//     // buffer.appendAssumeCapacity(x0);
//     // buffer.appendAssumeCapacity(y0);
//     // buffer.appendAssumeCapacity(x1);
//     // buffer.appendAssumeCapacity(y0);
//     // buffer.appendAssumeCapacity(x0);
//     // buffer.appendAssumeCapacity(y1);
// }

pub fn addVerticalQuadG2G(x0: f32, x1: f32, y0: f32, y1: f32, g0: f32, g1: f32, d0: u8) void {
    // const i = buf_n[d0];
    // buf[d0][i   ] = x0;
    // buf[d0][i+1 ] = y0;
    // buf[d0][i+2 ] = g0;
    // buf[d0][i+3 ] = g0;
    // buf[d0][i+4 ] = g0;
    // buf[d0][i+5 ] = g0;
    // buf[d0][i+6 ] = x1;
    // buf[d0][i+7 ] = y0;
    // buf[d0][i+8 ] = g0;
    // buf[d0][i+9 ] = g0;
    // buf[d0][i+10] = g0;
    // buf[d0][i+11] = g0;
    // buf[d0][i+12] = x1;
    // buf[d0][i+13] = y1;
    // buf[d0][i+14] = g1;
    // buf[d0][i+15] = g1;
    // buf[d0][i+16] = g1;
    // buf[d0][i+17] = g1;
    // buf[d0][i+18] = x0;
    // buf[d0][i+19] = y1;
    // buf[d0][i+20] = g1;
    // buf[d0][i+21] = g1;
    // buf[d0][i+22] = g1;
    // buf[d0][i+23] = g1;
    // buf_n[d0] += 24;
    const ctr = 0.0;
    const i = buf_n[d0];
    buf[d0][i   ] = x0;
    buf[d0][i+1 ] = y0;
    buf[d0][i+2 ] = g0;
    buf[d0][i+3 ] = g0;
    buf[d0][i+4 ] = g0;
    buf[d0][i+5 ] = g0;
    buf[d0][i+6 ] = 1e10;
    buf[d0][i+7 ] = ctr;
    buf[d0][i+8 ] = x1;
    buf[d0][i+9 ] = y0;
    buf[d0][i+10] = g0;
    buf[d0][i+11] = g0;
    buf[d0][i+12] = g0;
    buf[d0][i+13] = g0;
    buf[d0][i+14] = 1e10;
    buf[d0][i+15] = ctr;
    buf[d0][i+16] = x1;
    buf[d0][i+17] = y1;
    buf[d0][i+18] = g1;
    buf[d0][i+19] = g1;
    buf[d0][i+20] = g1;
    buf[d0][i+21] = g1;
    buf[d0][i+22] = 1e10;
    buf[d0][i+23] = ctr;
    buf[d0][i+24] = x0;
    buf[d0][i+25] = y1;
    buf[d0][i+26] = g1;
    buf[d0][i+27] = g1;
    buf[d0][i+28] = g1;
    buf[d0][i+29] = g1;
    buf[d0][i+30] = 1e10;
    buf[d0][i+31] = ctr;
    buf_n[d0] += 32;
}

pub fn addVerticalTexturedQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32,
                                u_0: f32, u_1: f32, v0: f32, v1: f32,
                                r: f32, g: f32, b: f32, a: f32,
                                h: f32, ctr: f32, d0: u8, t: u32) void {
    _ = t;
    _ = v1;
    _ = v0;
    _ = u_1;
    _ = u_0;
    const i = buf_n[d0];
    // const h = y2 - y0;
    buf[d0][i   ] = x0;
    buf[d0][i+1 ] = y0;
    buf[d0][i+2 ] = r;
    buf[d0][i+3 ] = g;
    buf[d0][i+4 ] = b;
    buf[d0][i+5 ] = a;
    buf[d0][i+6 ] = h;
    buf[d0][i+7 ] = ctr;
    buf[d0][i+8 ] = x1;
    buf[d0][i+9 ] = y1;
    buf[d0][i+10] = r;
    buf[d0][i+11] = g;
    buf[d0][i+12] = b;
    buf[d0][i+13] = a;
    buf[d0][i+14] = h;
    buf[d0][i+15] = ctr;
    buf[d0][i+16] = x1;
    buf[d0][i+17] = y2;
    buf[d0][i+18] = r;
    buf[d0][i+19] = g;
    buf[d0][i+20] = b;
    buf[d0][i+21] = a;
    buf[d0][i+22] = h;
    buf[d0][i+23] = ctr;
    buf[d0][i+24] = x0;
    buf[d0][i+25] = y3;
    buf[d0][i+26] = r;
    buf[d0][i+27] = g;
    buf[d0][i+28] = b;
    buf[d0][i+29] = a;
    buf[d0][i+30] = h;
    buf[d0][i+31] = ctr;
    buf_n[d0] += 32;
    // buf[d0][i+1 ] = y0;
    // buf[d0][i+2 ] = r;
    // buf[d0][i+3 ] = g;
    // buf[d0][i+4 ] = b;
    // buf[d0][i+5 ] = a;
    // buf[d0][i+6 ] = x1;
    // buf[d0][i+7 ] = y1;
    // buf[d0][i+8 ] = r;
    // buf[d0][i+9 ] = g;
    // buf[d0][i+10] = b;
    // buf[d0][i+11] = a;
    // buf[d0][i+12] = x1;
    // buf[d0][i+13] = y2;
    // buf[d0][i+14] = r;
    // buf[d0][i+15] = g;
    // buf[d0][i+16] = b;
    // buf[d0][i+17] = a;
    // buf[d0][i+18] = x0;
    // buf[d0][i+19] = y3;
    // buf[d0][i+20] = r;
    // buf[d0][i+21] = g;
    // buf[d0][i+22] = b;
    // buf[d0][i+23] = a;
    // buf_n[d0] += 24;
}

pub fn addVerticalQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32,
                        r: f32, g: f32, b: f32, a: f32,
                        h: f32, ctr: f32, d0: u8) void {
    const i = buf_n[d0];
    // const h = y2 - y0;
    buf[d0][i   ] = x0;
    buf[d0][i+1 ] = y0;
    buf[d0][i+2 ] = r;
    buf[d0][i+3 ] = g;
    buf[d0][i+4 ] = b;
    buf[d0][i+5 ] = a;
    buf[d0][i+6 ] = h;
    buf[d0][i+7 ] = ctr;
    buf[d0][i+8 ] = x1;
    buf[d0][i+9 ] = y1;
    buf[d0][i+10] = r;
    buf[d0][i+11] = g;
    buf[d0][i+12] = b;
    buf[d0][i+13] = a;
    buf[d0][i+14] = h;
    buf[d0][i+15] = ctr;
    buf[d0][i+16] = x1;
    buf[d0][i+17] = y2;
    buf[d0][i+18] = r;
    buf[d0][i+19] = g;
    buf[d0][i+20] = b;
    buf[d0][i+21] = a;
    buf[d0][i+22] = h;
    buf[d0][i+23] = ctr;
    buf[d0][i+24] = x0;
    buf[d0][i+25] = y3;
    buf[d0][i+26] = r;
    buf[d0][i+27] = g;
    buf[d0][i+28] = b;
    buf[d0][i+29] = a;
    buf[d0][i+30] = h;
    buf[d0][i+31] = ctr;
    buf_n[d0] += 32;
    // const i = buf_n[d0];
    // const h = y2 - y0;
    // buf[d0][i   ] = x0;
    // buf[d0][i+1 ] = y0;
    // buf[d0][i+2 ] = r;
    // buf[d0][i+3 ] = g;
    // buf[d0][i+4 ] = b;
    // buf[d0][i+5 ] = a;
    // buf[d0][i+6 ] = h;
    // buf[d0][i+7 ] = x1;
    // buf[d0][i+8 ] = y1;
    // buf[d0][i+9 ] = r;
    // buf[d0][i+10] = g;
    // buf[d0][i+11] = b;
    // buf[d0][i+12] = a;
    // buf[d0][i+13] = h;
    // buf[d0][i+14] = x1;
    // buf[d0][i+15] = y2;
    // buf[d0][i+16] = r;
    // buf[d0][i+17] = g;
    // buf[d0][i+18] = b;
    // buf[d0][i+19] = a;
    // buf[d0][i+20] = h;
    // buf[d0][i+21] = x0;
    // buf[d0][i+22] = y3;
    // buf[d0][i+23] = r;
    // buf[d0][i+24] = g;
    // buf[d0][i+25] = b;
    // buf[d0][i+26] = a;
    // buf[d0][i+27] = h;
    // buf_n[d0] += 28;
    // const i = buf_n[d0];
    // buf[d0][i   ] = x0;
    // buf[d0][i+1 ] = y0;
    // buf[d0][i+2 ] = r;
    // buf[d0][i+3 ] = g;
    // buf[d0][i+4 ] = b;
    // buf[d0][i+5 ] = a;
    // buf[d0][i+6 ] = x1;
    // buf[d0][i+7 ] = y1;
    // buf[d0][i+8 ] = r;
    // buf[d0][i+9 ] = g;
    // buf[d0][i+10] = b;
    // buf[d0][i+11] = a;
    // buf[d0][i+12] = x1;
    // buf[d0][i+13] = y2;
    // buf[d0][i+14] = r;
    // buf[d0][i+15] = g;
    // buf[d0][i+16] = b;
    // buf[d0][i+17] = a;
    // buf[d0][i+18] = x0;
    // buf[d0][i+19] = y3;
    // buf[d0][i+20] = r;
    // buf[d0][i+21] = g;
    // buf[d0][i+22] = b;
    // buf[d0][i+23] = a;
    // buf_n[d0] += 24;
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn reloadShaders() !void {
    log_gfx.info("Reloading shaders", .{});

    const sp = gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "base.vert",
        cfg.gfx.shader_dir ++ "base.frag") catch |e| {

        log_gfx.err("Error reloading shaders: {}", .{e});
        return;
    };

    try gfx_core.deleteShaderProgram(shader_program);
    shader_program = sp;

    // Reset all uniforms
    setProjection(gfx_core.getWindowWidth(), gfx_core.getWindowHeight());
}

pub fn renderFrame() !void {

    try gfx_core.useShaderProgram(shader_program);
    try gfx_core.setUniform1f(shader_program, "u_center",
                              @as(f32, @floatFromInt(gfx_core.getWindowHeight()/2)));

    try gfx_core.bindVAO(vao_0);
    try gfx_core.bindBuffer(.Element, ebo);
    try setVertexAttributeMode(.PxyCrgbaH);

    var i: u32 = cfg.gfx.depth_levels_max;
    while (i > 0) : (i -= 1) {
        try gfx_core.bindVBOAndBufferSubData(0, vbo_0, @intCast(buf_n[i-1]), &buf[i-1]);

        // Draw based on indices. Buffers accumulate 2d vertices, which is 24 values per
        // vertical polygon (4 vertices x,y, rgba). Drawing triangles, this is 6 indices
        try gfx_core.drawElements(.Triangles, @intCast(buf_n[i-1]*6/32));

        buf_n[i-1] = 0;
    }
    // try gfx_core.bindVBOAndBufferSubData(0, vbo_0, buf_n_lines, buf_lines);
    // try gfx_core.drawArrays(.Lines, 0, @intCast(buf_n_lines / 6));
    buf_n_lines = 0;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx = std.log.scoped(.gfx_rw);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var shader_program: u32 = 0;
var ebo: u32 = 0;
var vao_0: u32 = 0;
var vao_1: u32 = 0;
var vbo_0: u32 = 0;
var vbo_1: u32 = 0;

const buf_size = 4096*2*32;
const buf_type = [cfg.gfx.depth_levels_max][buf_size]f32;
const buf_size_lines = 4096*2*6*cfg.rc.segments_max;
const buf_type_lines = [buf_size_lines]f32;

var buf: *buf_type = undefined;
var buf_n: [cfg.gfx.depth_levels_max]usize = undefined;
var buf_lines: *buf_type_lines = undefined;
var buf_n_lines: u32 = 0;

fn  handleWindowResize(w: u64, h: u64) void {
    setProjection(w, h);
    log_gfx.debug("Window resize callback triggered, w = {}, h = {}", .{w, h});
}

fn setProjection(w: u64, h: u64) void {
    // Adjust projection for vertex shader
    // (simple ortho projection, therefore, no explicit matrix)
    const w_r = 2.0/@as(f32, @floatFromInt(w));
    const h_r = 2.0/@as(f32, @floatFromInt(h));
    const o_w = @as(f32, @floatFromInt(w/2));
    const o_h = @as(f32, @floatFromInt(h/2));
    gfx_core.setUniform4f(shader_program, "t", w_r, h_r, o_w, o_h) catch |e| {
        log_gfx.err("{}", .{e});
    };
}

//-----------------------------------------------------------------------------//
//   Predefined vertex attribute modes
//-----------------------------------------------------------------------------//

fn setVertexAttributeMode(m: AttributeMode) !void {
    switch (m) {
        .Pxy => {
            try gfx_core.enableVertexAttributes(0);
            c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), null);
            // if (!glCheckError()) return GraphicsError.OpenGLFailed;
        },
        .PxyCrgba => {
            try gfx_core.enableVertexAttributes(0);
            c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), null);
            // if (!glCheckError()) return GraphicsError.OpenGLFailed;
            try gfx_core.enableVertexAttributes(1);
            c.__glewVertexAttribPointer.?(1, 4, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
            // if (!glCheckError()) return GraphicsError.OpenGLFailed;
        },
        .PxyCrgbaH => {
            try gfx_core.enableVertexAttributes(0);
            c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, 8 * @sizeOf(f32), null);
            // if (!glCheckError()) return GraphicsError.OpenGLFailed;
            try gfx_core.enableVertexAttributes(1);
            c.__glewVertexAttribPointer.?(1, 4, c.GL_FLOAT, c.GL_FALSE, 8 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
            // if (!glCheckError()) return GraphicsError.OpenGLFailed;
            try gfx_core.enableVertexAttributes(2);
            c.__glewVertexAttribPointer.?(2, 2, c.GL_FLOAT, c.GL_FALSE, 8 * @sizeOf(f32), @ptrFromInt(6 * @sizeOf(f32)));
            // if (!glCheckError()) return GraphicsError.OpenGLFailed;
        },
        else => {}
    }
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//
