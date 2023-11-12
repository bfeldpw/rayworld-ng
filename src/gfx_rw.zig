const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");
const stats = @import("stats.zig");

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    ebo = try gfx_core.createBuffer();
    vbo_0 = try gfx_core.createBuffer();
    // vbo_1 = try gfx_core.createVBO();
    vao_0 = try gfx_core.createVAO();
    // vao_1 = try gfx_core.createVAO();
    try initShaders();
    try gfx_core.addWindowResizeCallback(&handleWindowResize);

    try buffer.ensureTotalCapacity(buffer_size);
    try gfx_core.bindVBOAndReserveBuffer(.Array, vbo_0, buffer_size, .Dynamic);
    // try gfx_core.bindVBOAndReserveBuffer(.Array, vbo_1, buffer_size, .Dynamic);

    var ebo_buf = std.ArrayList(u32).init(allocator);
    try ebo_buf.ensureTotalCapacity(buffer_size*6);
    var i: u32 = 0;
    while (i < buffer_size) : (i += 1) {
        ebo_buf.appendAssumeCapacity(0 + 4 * i);
        ebo_buf.appendAssumeCapacity(1 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(1 + 4 * i);
        ebo_buf.appendAssumeCapacity(3 + 4 * i);
    }
    try gfx_core.bindEBOAndBufferData(ebo, buffer_size*6, ebo_buf.items, .Static);
    ebo_buf.deinit();
}

pub fn deinit() void {
    buffer.deinit();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

pub fn initShaders() !void {
    log_gfx.info("Processing shaders", .{});

    shader_program = try gfx_core.createShaderProgramFromFiles(
        "/home/bfeld/projects/rayworld-ng/resource/shader/base.vert",
        "/home/bfeld/projects/rayworld-ng/resource/shader/base.frag");
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Fill render pipeline
//-----------------------------------------------------------------------------//

pub fn addVerticalQuad(x0: f32, x1: f32, y0: f32, y1: f32, r: f32, g: f32, b: f32, a: f32, d0: u8) void {
    _ = y1;
    _ = y0;
    _ = x1;
    _ = x0;
    _ = d0;
    _ = a;
    _ = b;
    _ = g;
    _ = r;
    // buffer.appendAssumeCapacity(x0);
    // buffer.appendAssumeCapacity(y0);
    // buffer.appendAssumeCapacity(x1);
    // buffer.appendAssumeCapacity(y0);
    // buffer.appendAssumeCapacity(x0);
    // buffer.appendAssumeCapacity(y1);
}

pub fn addVerticalTexturedQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32, u_0: f32, u_1: f32, v0: f32, v1: f32, r: f32, g: f32, b: f32, a: f32, d0: u8, t: u32) void {
    _ = t;
    _ = d0;
    _ = a;
    _ = b;
    _ = g;
    _ = r;
    _ = v1;
    _ = v0;
    _ = u_1;
    _ = u_0;
    buffer.appendAssumeCapacity(x0);
    buffer.appendAssumeCapacity(y0);
    buffer.appendAssumeCapacity(x1);
    buffer.appendAssumeCapacity(y1);
    buffer.appendAssumeCapacity(x0);
    buffer.appendAssumeCapacity(y3);
    buffer.appendAssumeCapacity(x0);
    buffer.appendAssumeCapacity(y3);
    buffer.appendAssumeCapacity(x1);
    buffer.appendAssumeCapacity(y1);
    buffer.appendAssumeCapacity(x1);
    buffer.appendAssumeCapacity(y2);
}

pub fn addVerticalQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32, r: f32, g: f32, b: f32, a: f32, d0: u8) void {
    _ = r;
    _ = g;
    _ = b;
    _ = a;
    _ = d0;
    buffer.appendAssumeCapacity(x0);
    buffer.appendAssumeCapacity(y0);
    buffer.appendAssumeCapacity(x1);
    buffer.appendAssumeCapacity(y1);
    buffer.appendAssumeCapacity(x0);
    buffer.appendAssumeCapacity(y3);
    buffer.appendAssumeCapacity(x0);
    buffer.appendAssumeCapacity(y3);
    buffer.appendAssumeCapacity(x1);
    buffer.appendAssumeCapacity(y1);
    buffer.appendAssumeCapacity(x1);
    buffer.appendAssumeCapacity(y2);
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn renderFrame() !void {

    try gfx_core.useShaderProgram(shader_program);

    try gfx_core.bindVAO(vao_0);
    try gfx_core.bindVBOAndBufferSubData(.Array, 0, vbo_0, @intCast(buffer.items.len), buffer.items);
    // log_gfx.debug("buffer {} on {}", .{buffer.items.len, vbo_0});
    try gfx_core.setVertexAttributeMode(.Pxy);

    // try gfx_core.bindVAO(vao_1);
    // try gfx_core.bindVBO(.Array, vbo_1);
    try gfx_core.drawArrays(.Triangles, 0, @as(i32, @intCast(buffer.items.len)));
    // log_gfx.debug("draw {} on {}", .{buffer_len_prev, vbo_1});
    // try gfx_core.drawArrays(.Triangles, 0, buffer_len_prev);
    // std.mem.swap(u32, &vbo_0, &vbo_1);
    // std.mem.swap(u32, &vao_0, &vao_1);

    buffer_len_prev = @intCast(buffer.items.len);
    // log_gfx.debug("store {}", .{buffer_len_prev});
    buffer.clearRetainingCapacity();
    // log_gfx.debug("-------- reset -------", .{});
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

const buffer_size = 4096*2*6*cfg.gfx.depth_levels_max;
// const buffer_size = 10;
var buffer = std.ArrayList(f32).init(allocator);
var buffer_len_prev: i32 = buffer_size;

fn  handleWindowResize(w: u64, h: u64) void {

    // Adjust projection for vertex shader
    // (simple ortho projection, therefore, no explicit matrix)
    const w_r = 2.0/@as(f32, @floatFromInt(w));
    const h_r = 2.0/@as(f32, @floatFromInt(h));
    const o_w = @as(f32, @floatFromInt(w)) * 0.5;
    const o_h = @as(f32, @floatFromInt(h)) * 0.5;
    gfx_core.setUniform4f(shader_program, "t", w_r, h_r, o_w, o_h) catch |e| {
        log_gfx.err("{}", .{e});
    };
    log_gfx.debug("Window resize callback triggered, w = {}, h = {}", .{w, h});
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//
