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
    PxyCrgbaH,
    PxyCrgbaTuvH
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    vao_0 = try gfx_core.createVAO();
    ebo = try gfx_core.createBuffer();
    vbo_0 = try gfx_core.createBuffer();
    vbo_1 = try gfx_core.createBuffer();
    colors.vbo = try gfx_core.createBuffer();
    try initShaders();
    try gfx_core.addWindowResizeCallback(&handleWindowResize);

    var s: u32 = scene.buf_size;
    if (verts_rays.buf_size > s) s = verts_rays.buf_size;
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, vbo_0, s, .Dynamic);
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, vbo_1, verts_rays.buf_size, .Dynamic);
    try gfx_core.bindVBOAndReserveBuffer(u32, .Array, colors.vbo, colors.buf_size, .Dynamic);

    var ebo_buf = std.ArrayList(u32).init(allocator);
    try ebo_buf.ensureTotalCapacity(scene.buf_size*6);
    var i: u32 = 0;
    while (i < scene.buf_size) : (i += 1) {
        ebo_buf.appendAssumeCapacity(0 + 4 * i);
        ebo_buf.appendAssumeCapacity(1 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(3 + 4 * i);
        ebo_buf.appendAssumeCapacity(0 + 4 * i);
    }
    try gfx_core.bindEBOAndBufferData(ebo, scene.buf_size*6, ebo_buf.items, .Static);
    ebo_buf.deinit();

    //--- Setup background ---//
    vert_bg.vbo = try gfx_core.createBuffer();
    colors_bg.vbo = try gfx_core.createBuffer();
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, vert_bg.vbo, vert_bg.buf_size, .Dynamic);
    try gfx_core.bindVBOAndReserveBuffer(u32, .Array, colors_bg.vbo, colors_bg.buf_size, .Dynamic);

    //--- Setup scene ---//
    scene.buf = try allocator.create(scene.buf_type);
    i = 0;
    while (i < cfg.gfx.depth_levels_max) : (i += 1) {
        scene.buf_n[i] = 0;
    }
    verts_rays.buf = try allocator.create(verts_rays.buf_type);

    colors.buf = try allocator.create(colors.buf_type);
    i = 0;
    while (i < cfg.gfx.depth_levels_max) : (i += 1) {
        colors.buf_n[i] = 0;
    }

    c.glEnable(c.GL_FRAMEBUFFER_SRGB);
}

pub fn deinit() void {
    allocator.destroy(scene.buf);
    allocator.destroy(verts_rays.buf);
    allocator.destroy(colors.buf);

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

pub fn initShaders() !void {
    log_gfx.info("Processing shaders", .{});

    shader_program_base = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "base.vert",
        cfg.gfx.shader_dir ++ "base.frag");
    shader_program_scene = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "scene.vert",
        cfg.gfx.shader_dir ++ "scene.frag");
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Fill render pipeline
//-----------------------------------------------------------------------------//

pub fn addLine(x0: f32, y0: f32, x1: f32, y1: f32, r: f32, g: f32, b: f32, a: f32) void {
    const i = verts_rays.buf_n;
    const br = verts_rays.buf;
    br[i   ] = x0;
    br[i+1 ] = y0;
    br[i+2 ] = r;
    br[i+3 ] = g;
    br[i+4 ] = b;
    br[i+5 ] = a;
    br[i+6 ] = x1;
    br[i+7 ] = y1;
    br[i+8 ] = r;
    br[i+9 ] = g;
    br[i+10] = b;
    br[i+11] = a;
    verts_rays.buf_n += 12;
}

pub fn addQuad(x0: f32, y0: f32, x1: f32, y1: f32, col: u32, d0: u8) void {
    const i = scene.buf_n[d0];
    const bd = &scene.buf[d0];
    bd[i  ] = x0;
    bd[i+1] = y0;
    bd[i+2] = x1;
    bd[i+3] = y0;
    bd[i+4] = x1;
    bd[i+5] = y1;
    bd[i+6] = x0;
    bd[i+7] = y1;
    scene.buf_n[d0] += 8;
    const ic = colors.buf_n[d0];
    const bc = &colors.buf[d0];
    bc[ic  ] = col;
    bc[ic+1] = col;
    bc[ic+2] = col;
    bc[ic+3] = col;
    colors.buf_n[d0] += 4;
}

pub fn addQuadBackground(x0: f32, x1: f32, y0: f32, y1: f32, g0: f32, g1: f32) void {
    const i = vert_bg.buf_n;
    const bd = &vert_bg.buf;
    bd[i   ] = x0;
    bd[i+1 ] = y0;
    bd[i+2 ] = x1;
    bd[i+3 ] = y0;
    bd[i+4 ] = x1;
    bd[i+5 ] = y1;
    bd[i+6 ] = x0;
    bd[i+7 ] = y1;
    vert_bg.buf_n += 8;
    const ic = colors_bg.buf_n;
    const bc = &colors_bg.buf;
    const g0_u32 = gfx_core.compressGrey(g0, g0);
    const g1_u32 = gfx_core.compressGrey(g1, g1);
    bc[ic  ] = g0_u32;
    bc[ic+1] = g0_u32;
    bc[ic+2] = g1_u32;
    bc[ic+3] = g1_u32;
    colors_bg.buf_n += 4;
}

pub fn addVerticalTexturedQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32,
                                u_0: f32, u_1: f32, v0: f32, v1: f32,
                                r: f32, g: f32, b: f32, a: f32,
                                h: f32, ctr: f32, d0: u8, t: u32) void {
    _ = t;
    const i = scene.buf_n[d0];
    const bd = &scene.buf[d0];
    bd[i   ] = x0;
    bd[i+1 ] = y0;
    bd[i+2 ] = r;
    bd[i+3 ] = g;
    bd[i+4 ] = b;
    bd[i+5 ] = a;
    bd[i+6 ] = u_0;
    bd[i+7 ] = v0;
    bd[i+8 ] = h;
    bd[i+9 ] = ctr;
    bd[i+10] = x1;
    bd[i+11] = y1;
    bd[i+12] = r;
    bd[i+13] = g;
    bd[i+14] = b;
    bd[i+15] = a;
    bd[i+16] = u_1;
    bd[i+17] = v0;
    bd[i+18] = h;
    bd[i+19] = ctr;
    bd[i+20] = x1;
    bd[i+21] = y2;
    bd[i+22] = r;
    bd[i+23] = g;
    bd[i+24] = b;
    bd[i+25] = a;
    bd[i+26] = u_1;
    bd[i+27 ] = v1;
    bd[i+28] = h;
    bd[i+29] = ctr;
    bd[i+30] = x0;
    bd[i+31] = y3;
    bd[i+32] = r;
    bd[i+33] = g;
    bd[i+34] = b;
    bd[i+35] = a;
    bd[i+36] = u_0;
    bd[i+37] = v1;
    bd[i+38] = h;
    bd[i+39] = ctr;
    scene.buf_n[d0] += scene.attrib_size;
}

pub fn addVerticalQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32,
                        r: f32, g: f32, b: f32, a: f32,
                        h: f32, ctr: f32, d0: u8) void {
    _ = d0;
    _ = ctr;
    _ = h;
    _ = a;
    _ = b;
    _ = g;
    _ = r;
    _ = y3;
    _ = y2;
    _ = y1;
    _ = y0;
    _ = x1;
    _ = x0;
    // const i = buf_n[d0];
    // buf[d0][i   ] = x0;
    // buf[d0][i+1 ] = y0;
    // buf[d0][i+2 ] = r;
    // buf[d0][i+3 ] = g;
    // buf[d0][i+4 ] = b;
    // buf[d0][i+5 ] = a;
    // buf[d0][i+6 ] = h;
    // buf[d0][i+7 ] = ctr;
    // buf[d0][i+8 ] = x1;
    // buf[d0][i+9 ] = y1;
    // buf[d0][i+10] = r;
    // buf[d0][i+11] = g;
    // buf[d0][i+12] = b;
    // buf[d0][i+13] = a;
    // buf[d0][i+14] = h;
    // buf[d0][i+15] = ctr;
    // buf[d0][i+16] = x1;
    // buf[d0][i+17] = y2;
    // buf[d0][i+18] = r;
    // buf[d0][i+19] = g;
    // buf[d0][i+20] = b;
    // buf[d0][i+21] = a;
    // buf[d0][i+22] = h;
    // buf[d0][i+23] = ctr;
    // buf[d0][i+24] = x0;
    // buf[d0][i+25] = y3;
    // buf[d0][i+26] = r;
    // buf[d0][i+27] = g;
    // buf[d0][i+28] = b;
    // buf[d0][i+29] = a;
    // buf[d0][i+30] = h;
    // buf[d0][i+31] = ctr;
    // buf_n[d0] += 32;
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn reloadShaders() !void {
    log_gfx.info("Reloading shaders", .{});

    const sp_base = gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "base.vert",
        cfg.gfx.shader_dir ++ "base.frag") catch |e| {

        log_gfx.err("Error reloading shaders: {}", .{e});
        return;
    };

    const sp_scene = gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "scene.vert",
        cfg.gfx.shader_dir ++ "scene.frag") catch |e| {

        log_gfx.err("Error reloading shaders: {}", .{e});
        return;
    };

    try gfx_core.deleteShaderProgram(shader_program_base);
    shader_program_base = sp_base;
    try gfx_core.deleteShaderProgram(shader_program_scene);
    shader_program_scene = sp_scene;

    // Reset all uniforms
    setProjection(gfx_core.getWindowWidth(), gfx_core.getWindowHeight());
}

pub fn renderFrame() !void {

    //--- Floor and Ceiling ---//
    try gfx_core.useShaderProgram(shader_program_base);
    try gfx_core.bindVAO(vao_0);
    // try gfx_core.bindVBOAndBufferSubData(0, vbo_0, @intCast(scene.buf_n[0]), &scene.buf[0]);
    try gfx_core.bindVBOAndBufferSubData(f32, 0, vert_bg.vbo, @intCast(vert_bg.buf_n), &vert_bg.buf);
    try gfx_core.enableVertexAttributes(0);
    try gfx_core.setupVertexAttributesFloat(0, 2, 0, 0);
    try gfx_core.bindVBOAndBufferSubData(u32, 0, colors_bg.vbo, @intCast(colors_bg.buf_n), &colors_bg.buf);
    try gfx_core.enableVertexAttributes(1);
    try gfx_core.setupVertexAttributesUInt32(1, 1, 0, 0);
    try gfx_core.disableVertexAttributes(2);
    try gfx_core.disableVertexAttributes(3);
    try gfx_core.bindEBO(ebo);
    try gfx_core.drawElements(.Triangles, @intCast(vert_bg.buf_n*6/8));
    vert_bg.buf_n = 0;
    colors_bg.buf_n = 0;
    // try setVertexAttributeMode(.PxyCrgba);
    // try gfx_core.drawElements(.Triangles, @intCast(scene.buf_n[0]*6/24));
    // scene.buf_n[0] = 0;

    //--- Scene ---//
    try gfx_core.useShaderProgram(shader_program_scene);
    try gfx_core.setUniform1f(shader_program_scene, "u_center",
                              @as(f32, @floatFromInt(gfx_core.getWindowHeight()/2)));

    try gfx_core.bindVBO(vbo_0);
    try gfx_core.bindEBO(ebo);
    try setVertexAttributeMode(.PxyCrgbaTuvH);

    var i: u32 = cfg.gfx.depth_levels_max;
    while (i > 1) : (i -= 1) {
        try gfx_core.bindVBOAndBufferSubData(f32, 0, vbo_0, @intCast(scene.buf_n[i-1]), &scene.buf[i-1]);

        // Draw based on indices.
        try gfx_core.drawElements(.Triangles, @intCast(scene.buf_n[i-1]*6/scene.attrib_size));

        scene.buf_n[i-1] = 0;
    }

    //--- Map ---//
    try gfx_core.useShaderProgram(shader_program_base);
    // try setVertexAttributeMode(.PxyCrgba);
    try gfx_core.bindVBOAndBufferSubData(f32, 0, vbo_0, @intCast(scene.buf_n[0]), &scene.buf[0]);
    try gfx_core.enableVertexAttributes(0);
    try gfx_core.setupVertexAttributesFloat(0, 2, 0, 0);
    try gfx_core.bindVBOAndBufferSubData(u32, 0, colors.vbo, @intCast(colors.buf_n[0]), &colors.buf[0]);
    try gfx_core.enableVertexAttributes(1);
    try gfx_core.setupVertexAttributesUInt32(1, 1, 0, 0);
    try gfx_core.disableVertexAttributes(2);
    try gfx_core.disableVertexAttributes(3);
    try gfx_core.bindEBO(ebo);
    try gfx_core.drawElements(.Triangles, @intCast(scene.buf_n[0]*6/8));
    scene.buf_n[0] = 0;
    colors.buf_n[0] = 0;

    //--- Rays ---//
    // try gfx_core.bindVBO(vbo_1);
    try gfx_core.bindVBOAndBufferSubData(f32, 0, vbo_1, verts_rays.buf_n, verts_rays.buf);
    try setVertexAttributeMode(.PxyCrgba);
    try gfx_core.drawArrays(.Lines, 0, @intCast(verts_rays.buf_n / 6));
    verts_rays.buf_n = 0;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx = std.log.scoped(.gfx_rw);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var shader_program_base: u32 = 0;
var shader_program_scene: u32 = 0;
var ebo: u32 = 0;
var vao_0: u32 = 0;
var vbo_0: u32 = 0;
var vbo_1: u32 = 0;
// var vbo_col: u32 = 0;

const colors_bg = struct {
    const buf_size = 16;
    const buf_type = [colors_bg.buf_size]u32;

    var buf: buf_type = undefined;
    var buf_n: usize = 0;
    var vbo: u32 = 0;
};

const vert_bg = struct {
    const buf_size = 32;
    const buf_type = [buf_size]f32;

    var buf: buf_type = undefined;
    var buf_n: usize = 0;
    var vbo: u32 = 0;
};

// const colors_map = struct {
//     const buf_size = ;
//     const buf_type = [colors_bg.buf_size]u32;

//     var buf: buf_type = undefined;
//     var buf_n: usize = 0;
//     var vbo: u32 = 0;
// };

// const vert_map = struct {
//     const buf_size = 16;
//     const buf_type = [buf_size]f32;

//     var buf: buf_type = undefined;
//     var buf_n: usize = 0;
//     var vbo: u32 = 0;
// };

const colors = struct {
    const buf_size = 4096*2;
    const buf_type = [cfg.gfx.depth_levels_max][colors.buf_size]u32;

    var buf: *colors.buf_type = undefined;
    var buf_n: [cfg.gfx.depth_levels_max]usize = undefined;
    var vbo: u32 = 0;
};

const scene = struct {
    const attrib_size = 40;
    const buf_size = 4096*2*scene.attrib_size;
    const buf_type = [cfg.gfx.depth_levels_max][scene.buf_size]f32;

    var buf: *scene.buf_type = undefined;
    var buf_n: [cfg.gfx.depth_levels_max]usize = undefined;
};

const verts_rays = struct {
    const buf_size = 4096*2*6*cfg.rc.segments_max;
    const buf_type = [verts_rays.buf_size]f32;

    var buf: *verts_rays.buf_type = undefined;
    var buf_n: u32 = 0;
};
// const buf_size = 4096*2*40;
// const buf_type = [cfg.gfx.depth_levels_max][buf_size]f32;
// const buf_size_lines = 4096*2*6*cfg.rc.segments_max;


fn handleWindowResize(w: u64, h: u64) void {
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
    gfx_core.useShaderProgram(shader_program_base) catch |e| {
        log_gfx.err("{}", .{e});
    };
    gfx_core.setUniform4f(shader_program_base, "t", w_r, h_r, o_w, o_h) catch |e| {
        log_gfx.err("{}", .{e});
    };
    gfx_core.useShaderProgram(shader_program_scene) catch |e| {
        log_gfx.err("{}", .{e});
    };
    gfx_core.setUniform4f(shader_program_scene, "t", w_r, h_r, o_w, o_h) catch |e| {
        log_gfx.err("{}", .{e});
    };
    // gfx_core.setUniform1f(shader_program_scene, "u_center",
    //                           @as(f32, @floatFromInt(gfx_core.getWindowHeight()/2))) catch |e| {
    //     log_gfx.err("{}", .{e});
    // };
}

//-----------------------------------------------------------------------------//
//   Predefined vertex attribute modes
//-----------------------------------------------------------------------------//

fn setVertexAttributeMode(m: AttributeMode) !void {
    switch (m) {
        .Pxy => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.disableVertexAttributes(1);
            try gfx_core.disableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 2, 0);
        },
        .PxyCrgba => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.enableVertexAttributes(1);
            try gfx_core.disableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 6, 0);
            try gfx_core.setupVertexAttributesFloat(1, 4, 6, 2);
        },
        .PxyCrgbaH => {
            try gfx_core.enableVertexAttributes(0);
            try gfx_core.enableVertexAttributes(1);
            try gfx_core.enableVertexAttributes(2);
            try gfx_core.disableVertexAttributes(3);
            try gfx_core.setupVertexAttributesFloat(0, 2, 8, 0);
            try gfx_core.setupVertexAttributesFloat(1, 4, 8, 2);
            try gfx_core.setupVertexAttributesFloat(2, 2, 8, 6);
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
        },
        else => {}
    }
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//
