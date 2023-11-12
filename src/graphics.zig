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


    vbo = try gfx_core.createVBO();
    vao = try gfx_core.createVAO();
    try initShaders();
    try allocMemory();

    // var value_quads = quads.getPtr(1);
    // if (value_quads) |val| {
    //     for (&val.i_verts) |*v| {
    //         v.* = 0;
    //     }
    //     for (&val.i_cols) |*v| {
    //         v.* = 0;
    //     }
    //     for (&val.n) |*v| {
    //         v.* = 0;
    //     }
    // }
}

pub fn deinit() void {
    draw_call_statistics.printStats();
    quad_statistics.printStats();
    quad_tex_statistics.printStats();


    freeMemory();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

pub fn initShaders() !void {
    log_gfx.info("Preparing shaders", .{});

    shader_program = try gfx_core.createShaderProgramFromFiles(
        "/home/bfeld/projects/rayworld-ng/resource/shader/base.vert",
        "/home/bfeld/projects/rayworld-ng/resource/shader/base.frag");
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//


pub fn startBatchLine() void {
    gfx_core.disableTexturing()();
    // c.glBegin(c.GL_LINES);
}

pub fn startBatchLineTextured() void {
    gfx_core.enableTexturing();
    // c.glBegin(c.GL_LINES);
}

pub fn startBatchQuads() void {
    gfx_core.disableTexturing();
    // c.glBegin(c.GL_QUADS);
}

pub fn startBatchQuadsTextured() void {
    gfx_core.disableTexturing()();
    // c.glBegin(c.GL_QUADS);
}

pub fn drawCircle(x: f32, y: f32, r: f32) void {
    _ = r;
    _ = y;
    _ = x;
    const nr_of_segments = 100.0;

    gfx_core.disableTexturing();
    // c.glBegin(c.GL_LINE_LOOP);
    var angle: f32 = 0.0;
    const inc = 2.0 * std.math.pi / nr_of_segments;
    while (angle < 2.0 * std.math.pi) : (angle += inc) {
        // c.glVertex2f(r * @cos(angle) + x, r * @sin(angle) + y);
    }
    // c.glEnd();
}

pub fn drawLine(x0: f32, y0: f32, x1: f32, y1: f32) void {
    _ = y1;
    _ = x1;
    _ = y0;
    _ = x0;
    gfx_core.disableTexturing();
    // c.glBegin(c.GL_LINES);
    // c.glVertex2f(x0, y0);
    // c.glVertex2f(x1, y1);
    // c.glEnd();
}

pub fn drawQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    _ = y1;
    _ = x1;
    _ = y0;
    _ = x0;
    // disableTexturing();
    // c.glBegin(c.GL_QUADS);
    // c.glVertex2f(x0, y0);
    // c.glVertex2f(x1, y0);
    // c.glVertex2f(x1, y1);
    // c.glVertex2f(x0, y1);
    // c.glEnd();
}

pub fn drawQuadTextured(x0: f32, y0: f32, x1: f32, y1: f32,
                        u_0: f32, v0: f32, u_1: f32, v1: f32) void {
    _ = v1;
    _ = u_1;
    _ = v0;
    _ = u_0;
    _ = y1;
    _ = x1;
    _ = y0;
    _ = x0;
    gfx_core.enableTexturing();
    // c.glBegin(c.GL_QUADS);
    // c.glTexCoord2f(u_0, v0); c.glVertex2f(x0, y0);
    // c.glTexCoord2f(u_1, v0); c.glVertex2f(x1, y0);
    // c.glTexCoord2f(u_1, v1); c.glVertex2f(x1, y1);
    // c.glTexCoord2f(u_0, v1); c.glVertex2f(x0, y1);
    // c.glEnd();
}

pub fn drawTriangle(x0: f32, y0: f32, x1: f32, y1: f32, x2: f32, y2: f32) void {
    _ = y2;
    _ = x2;
    _ = y1;
    _ = x1;
    _ = y0;
    _ = x0;
    gfx_core.disableTexturing();
    // c.glBegin(c.GL_TRIANGLES);
    // c.glVertex2f(x0, y0);
    // c.glVertex2f(x1, y1);
    // c.glVertex2f(x2, y2);
    // c.glEnd();
}

pub fn addLine(x0: f32, y0: f32, x1: f32, y1: f32) void {
    _ = y1;
    _ = x1;
    _ = y0;
    _ = x0;
    // c.glVertex3f(x0, y0, 1);
    // c.glVertex3f(x1, y1, 1);
}

pub fn addQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    _ = y1;
    _ = x1;
    _ = y0;
    _ = x0;
    // c.glVertex2f(x0, y0);
    // c.glVertex2f(x1, y0);
    // c.glVertex2f(x1, y1);
    // c.glVertex2f(x0, y1);
}

pub fn addQuadTextured(x0: f32, y0: f32, x1: f32, y1: f32,
                       u_0: f32, v0: f32, u_1: f32, v1: f32) void {
    _ = v1;
    _ = u_1;
    _ = v0;
    _ = u_0;
    _ = y1;
    _ = x1;
    _ = y0;
    _ = x0;
    // c.glTexCoord2f(u_0, v0); c.glVertex2f(x0, y0);
    // c.glTexCoord2f(u_1, v0); c.glVertex2f(x1, y0);
    // c.glTexCoord2f(u_1, v1); c.glVertex2f(x1, y1);
    // c.glTexCoord2f(u_0, v1); c.glVertex2f(x0, y1);
}

pub fn addVerticalQuad(x0: f32, x1: f32, y0: f32, y1: f32, r: f32, g: f32, b: f32, a: f32, d0: u8) void {
    var value = quads.getPtr(1);
    if (value) |v| {
        const d = depth_levels - d0 - 1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x0;
        v.verts[d][i_v + 1] = y0;
        v.verts[d][i_v + 2] = x1;
        v.verts[d][i_v + 3] = y0;
        v.verts[d][i_v + 4] = x1;
        v.verts[d][i_v + 5] = y1;
        v.verts[d][i_v + 6] = x0;
        v.verts[d][i_v + 7] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = r;
        v.cols[d][i_c + 1] = g;
        v.cols[d][i_c + 2] = b;
        v.cols[d][i_c + 3] = a;
        v.cols[d][i_c + 4] = r;
        v.cols[d][i_c + 5] = g;
        v.cols[d][i_c + 6] = b;
        v.cols[d][i_c + 7] = a;
        v.cols[d][i_c + 8] = r;
        v.cols[d][i_c + 9] = g;
        v.cols[d][i_c + 10] = b;
        v.cols[d][i_c + 11] = a;
        v.cols[d][i_c + 12] = r;
        v.cols[d][i_c + 13] = g;
        v.cols[d][i_c + 14] = b;
        v.cols[d][i_c + 15] = a;
        v.i_verts[d] += 8;
        v.i_cols[d] += 16;
        v.n[d] += 4;
        depth_levels_active.set(d);
        quad_statistics.inc();
    }
}

pub fn addVerticalQuadG2G(x0: f32, x1: f32, y0: f32, y1: f32, c0: f32, c1: f32, a: f32, d0: u8) void {
    var value = quads.getPtr(1);
    if (value) |v| {
        const d = depth_levels - d0 - 1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x0;
        v.verts[d][i_v + 1] = y0;
        v.verts[d][i_v + 2] = x1;
        v.verts[d][i_v + 3] = y0;
        v.verts[d][i_v + 4] = x1;
        v.verts[d][i_v + 5] = y1;
        v.verts[d][i_v + 6] = x0;
        v.verts[d][i_v + 7] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = c0;
        v.cols[d][i_c + 1] = c0;
        v.cols[d][i_c + 2] = c0;
        v.cols[d][i_c + 3] = a;
        v.cols[d][i_c + 4] = c0;
        v.cols[d][i_c + 5] = c0;
        v.cols[d][i_c + 6] = c0;
        v.cols[d][i_c + 7] = a;
        v.cols[d][i_c + 8] = c1;
        v.cols[d][i_c + 9] = c1;
        v.cols[d][i_c + 10] = c1;
        v.cols[d][i_c + 11] = a;
        v.cols[d][i_c + 12] = c1;
        v.cols[d][i_c + 13] = c1;
        v.cols[d][i_c + 14] = c1;
        v.cols[d][i_c + 15] = a;
        v.i_verts[d] += 8;
        v.i_cols[d] += 16;
        v.n[d] += 4;
        depth_levels_active.set(d);
        quad_statistics.inc();
    }
}

pub fn addVerticalQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32, r: f32, g: f32, b: f32, a: f32, d0: u8) void {
    var value = quads.getPtr(1);
    if (value) |v| {
        const d = depth_levels - d0 - 1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x0;
        v.verts[d][i_v + 1] = y0;
        v.verts[d][i_v + 2] = x1;
        v.verts[d][i_v + 3] = y1;
        v.verts[d][i_v + 4] = x1;
        v.verts[d][i_v + 5] = y2;
        v.verts[d][i_v + 6] = x0;
        v.verts[d][i_v + 7] = y3;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = r;
        v.cols[d][i_c + 1] = g;
        v.cols[d][i_c + 2] = b;
        v.cols[d][i_c + 3] = a;
        v.cols[d][i_c + 4] = r;
        v.cols[d][i_c + 5] = g;
        v.cols[d][i_c + 6] = b;
        v.cols[d][i_c + 7] = a;
        v.cols[d][i_c + 8] = r;
        v.cols[d][i_c + 9] = g;
        v.cols[d][i_c + 10] = b;
        v.cols[d][i_c + 11] = a;
        v.cols[d][i_c + 12] = r;
        v.cols[d][i_c + 13] = g;
        v.cols[d][i_c + 14] = b;
        v.cols[d][i_c + 15] = a;
        v.i_verts[d] += 8;
        v.i_cols[d] += 16;
        v.n[d] += 4;
        depth_levels_active.set(d);
        quad_statistics.inc();
    }
}

pub fn addVerticalTexturedQuad(x0: f32, x1: f32, y0: f32, y1: f32, u_0: f32, u_1: f32, v0: f32, v1: f32, r: f32, g: f32, b: f32, a: f32, d0: u8, t: u32) void {
    var value = quads_textured.getPtr(t);
    if (value) |v| {
        const d = depth_levels - d0 - 1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x0;
        v.verts[d][i_v + 1] = y0;
        v.verts[d][i_v + 2] = x1;
        v.verts[d][i_v + 3] = y0;
        v.verts[d][i_v + 4] = x1;
        v.verts[d][i_v + 5] = y1;
        v.verts[d][i_v + 6] = x0;
        v.verts[d][i_v + 7] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = r;
        v.cols[d][i_c + 1] = g;
        v.cols[d][i_c + 2] = b;
        v.cols[d][i_c + 3] = a;
        v.cols[d][i_c + 4] = r;
        v.cols[d][i_c + 5] = g;
        v.cols[d][i_c + 6] = b;
        v.cols[d][i_c + 7] = a;
        v.cols[d][i_c + 8] = r;
        v.cols[d][i_c + 9] = g;
        v.cols[d][i_c + 10] = b;
        v.cols[d][i_c + 11] = a;
        v.cols[d][i_c + 12] = r;
        v.cols[d][i_c + 13] = g;
        v.cols[d][i_c + 14] = b;
        v.cols[d][i_c + 15] = a;
        const i_t = v.i_texcs[d];
        v.texcs[d][i_t] = u_0;
        v.texcs[d][i_t + 1] = v0;
        v.texcs[d][i_t + 2] = u_1;
        v.texcs[d][i_t + 3] = v0;
        v.texcs[d][i_t + 4] = u_1;
        v.texcs[d][i_t + 5] = v1;
        v.texcs[d][i_t + 6] = u_0;
        v.texcs[d][i_t + 7] = v1;
        v.i_verts[d] += 8;
        v.i_cols[d] += 16;
        v.i_texcs[d] += 8;
        v.n[d] += 4;
        depth_levels_active.set(d);
        quad_tex_statistics.inc();
    }
}

pub fn addVerticalTexturedQuadY(x0: f32, x1: f32, y0: f32, y1: f32, y2: f32, y3: f32, u_0: f32, u_1: f32, v0: f32, v1: f32, r: f32, g: f32, b: f32, a: f32, d0: u8, t: u32) void {
    var value = quads_textured.getPtr(t);
    if (value) |v| {
        const d = depth_levels - d0 - 1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x0;
        v.verts[d][i_v + 1] = y0;
        v.verts[d][i_v + 2] = x1;
        v.verts[d][i_v + 3] = y1;
        v.verts[d][i_v + 4] = x1;
        v.verts[d][i_v + 5] = y2;
        v.verts[d][i_v + 6] = x0;
        v.verts[d][i_v + 7] = y3;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = r;
        v.cols[d][i_c + 1] = g;
        v.cols[d][i_c + 2] = b;
        v.cols[d][i_c + 3] = a;
        v.cols[d][i_c + 4] = r;
        v.cols[d][i_c + 5] = g;
        v.cols[d][i_c + 6] = b;
        v.cols[d][i_c + 7] = a;
        v.cols[d][i_c + 8] = r;
        v.cols[d][i_c + 9] = g;
        v.cols[d][i_c + 10] = b;
        v.cols[d][i_c + 11] = a;
        v.cols[d][i_c + 12] = r;
        v.cols[d][i_c + 13] = g;
        v.cols[d][i_c + 14] = b;
        v.cols[d][i_c + 15] = a;
        const i_t = v.i_texcs[d];
        v.texcs[d][i_t] = u_0;
        v.texcs[d][i_t + 1] = v0;
        v.texcs[d][i_t + 2] = u_1;
        v.texcs[d][i_t + 3] = v0;
        v.texcs[d][i_t + 4] = u_1;
        v.texcs[d][i_t + 5] = v1;
        v.texcs[d][i_t + 6] = u_0;
        v.texcs[d][i_t + 7] = v1;
        v.i_verts[d] += 8;
        v.i_cols[d] += 16;
        v.i_texcs[d] += 8;
        v.n[d] += 4;
        depth_levels_active.set(d);
        quad_tex_statistics.inc();
    }
}

pub fn endBatch() void {
    // c.glEnd();
}

pub fn endBatchTextured() void {
    // c.glEnd();
}

pub fn renderFrame() !void {
    var iter = depth_levels_active.iterator(.{});
    while (iter.next()) |d| {
    //     c.glEnableClientState(c.GL_VERTEX_ARRAY);
    //     c.glEnableClientState(c.GL_COLOR_ARRAY);
    //     c.glEnableClientState(c.GL_TEXTURE_COORD_ARRAY);
    //     c.glEnable(c.GL_TEXTURE_2D);
        var iter_quad_tex = quads_textured.iterator();
        while (iter_quad_tex.next()) |v| {
            if (v.value_ptr.n[d] > 0) {
    //             bindTexture(v.key_ptr.*);
    //             c.glVertexPointer(2, c.GL_FLOAT, 0, @ptrCast(&v.value_ptr.verts[d]));
    //             c.glColorPointer(4, c.GL_FLOAT, 0, @ptrCast(&v.value_ptr.cols[d]));
    //             c.glTexCoordPointer(2, c.GL_FLOAT, 0, @ptrCast(&v.value_ptr.texcs[d]));
    //             c.glDrawArrays(c.GL_QUADS, 0, @intCast(v.value_ptr.n[d]));
    //             if (!glCheckError()) return GraphicsError.OpenGLFailed;
                v.value_ptr.i_verts[d] = 0;
                v.value_ptr.i_cols[d] = 0;
                v.value_ptr.i_texcs[d] = 0;
                v.value_ptr.n[d] = 0;
                draw_call_statistics.inc();
            }
        }
    //     c.glDisableClientState(c.GL_TEXTURE_COORD_ARRAY);
    //     c.glDisable(c.GL_TEXTURE_2D);
        var value_quads = quads.getPtr(1);
        if (value_quads) |v| {
    //         c.glVertexPointer(2, c.GL_FLOAT, 0, @ptrCast(&v.verts[d]));
    //         c.glColorPointer(4, c.GL_FLOAT, 0, @ptrCast(&v.cols[d]));
    //         c.glDrawArrays(c.GL_QUADS, 0, @intCast(v.n[d]));
    //         if (!glCheckError()) return GraphicsError.OpenGLFailed;
            v.i_verts[d] = 0;
            v.i_cols[d] = 0;
            v.n[d] = 0;
            draw_call_statistics.inc();
        }
    //     c.glDisableClientState(c.GL_VERTEX_ARRAY);
    //     c.glDisableClientState(c.GL_COLOR_ARRAY);
    //     c.glDisableClientState(c.GL_TEXTURE_COORD_ARRAY);
    }
    const r = std.bit_set.Range{ .start = 0, .end = depth_levels - 1 };
    depth_levels_active.setRangeValue(r, false);

    draw_call_statistics.finishFrame();
    quad_statistics.finishFrame();
    quad_tex_statistics.finishFrame();

    try gfx_core.useShaderProgram(shader_program);
    try gfx_core.bindVAO(vao);

    const verts = [9]f32 {
        -0.5, -0.5, 0.0,
         0.5, -0.5, 0.0,
         0.0,  0.5, 0.0,
    };
    try gfx_core.bindVBO(vbo);
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, 9*@sizeOf(f32), &verts, c.GL_STATIC_DRAW);
    c.__glewVertexAttribPointer.?(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.__glewEnableVertexAttribArray.?(0);

    c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx = std.log.scoped(.gfx);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var frame_time: i64 = @intFromFloat(1.0 / 5.0 * 1.0e9);

var draw_call_statistics = stats.PerFrameCounter.init("Draw calls");
var quad_statistics = stats.PerFrameCounter.init("Quads");
var quad_tex_statistics = stats.PerFrameCounter.init("Quads textured");

/// Maximum quad buffer size for rendering
const quads_max = 4096 / cfg.sub_sampling_base * 8; // 4K resolution, minimm width 2px, maximum of 8 lines in each column of a depth layer
/// Maximum depth levels for rendering
const depth_levels = cfg.gfx.depth_levels_max;
/// Active depth levels
var depth_levels_active = std.bit_set.IntegerBitSet(depth_levels).initEmpty();

const Quads = struct {
    verts: [depth_levels][quads_max * 2 * 4]f32,
    cols: [depth_levels][quads_max * 4 * 4]f32,
    i_verts: [depth_levels]u32,
    i_cols: [depth_levels]u32,
    n: [depth_levels]u32,
};

const TexturedQuads = struct {
    verts: [depth_levels][quads_max * 2 * 4]f32,
    cols: [depth_levels][quads_max * 4 * 4]f32,
    texcs: [depth_levels][quads_max * 2 * 4]f32,
    i_verts: [depth_levels]u32,
    i_cols: [depth_levels]u32,
    i_texcs: [depth_levels]u32,
    n: [depth_levels]u32,
};

var quads = std.AutoHashMap(u8, Quads).init(allocator);
var quads_textured = std.AutoHashMap(u32, TexturedQuads).init(allocator);

fn allocMemory() !void {
    quads.put(1, .{ .verts = undefined, .cols = undefined, .i_verts = undefined, .i_cols = undefined, .n = undefined }) catch |e| {
        log_gfx.err("Allocation error ", .{});
        return e;
    };
}

fn freeMemory() void {
    quads.deinit();
    quads_textured.deinit();
}

var shader_program: u32 = 0;
var vao: u32 = 0;
var vbo: u32 = 0;

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

