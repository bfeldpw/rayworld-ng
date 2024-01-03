const std = @import("std");
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const fnt_gfx = @import("font_plugin_gfx.zig");
const gfx_core = @import("gfx_core.zig");
const gfx_base = @import("gfx_base.zig");
const map = @import("map.zig");
const sim = @import("sim.zig");
const stats = @import("stats.zig");

const builtin = @import("builtin");

//-----------------------------------------------------------------------------//
//   Error Sets / Enums
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    try initShaders();
    try gfx_core.addWindowResizeCallback(&handleWindowResize);

    vao_0 = try gfx_core.genVAO();
    try gfx_core.bindVAO(vao_0);

    // -- Setup EBO
    ebo = try gfx_core.genBuffer();
    var ebo_buf = std.ArrayList(u32).init(allocator);
    try ebo_buf.ensureTotalCapacity(verts_scene.buf_size*6);
    var i: u32 = 0;
    while (i < verts_scene.buf_size) : (i += 1) {
        ebo_buf.appendAssumeCapacity(0 + 4 * i);
        ebo_buf.appendAssumeCapacity(1 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(2 + 4 * i);
        ebo_buf.appendAssumeCapacity(3 + 4 * i);
        ebo_buf.appendAssumeCapacity(0 + 4 * i);
    }
    try gfx_core.bindEBOAndBufferData(ebo, verts_scene.buf_size*6, ebo_buf.items, .Static);
    ebo_buf.deinit();
    try gfx_core.bindEBO(ebo);

    //--- Setup background ---//
    verts_bg.vbo = try gfx_core.genBuffer();
    colors_bg.vbo = try gfx_core.genBuffer();
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, verts_bg.vbo, verts_bg.buf_size, .Dynamic);
    try gfx_core.bindVBOAndReserveBuffer(u32, .Array, colors_bg.vbo, colors_bg.buf_size, .Dynamic);

    //--- Setup scene ---//
    // colors_scene.vbo = try gfx_core.createBuffer();
    verts_scene.vbo = try gfx_core.genBuffer();
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, verts_scene.vbo, verts_scene.buf_size, .Dynamic);
    // try gfx_core.bindVBOAndReserveBuffer(u32, .Array, colors_scene.vbo, colors_scene.buf_size, .Dynamic);
    // verts_scene.buf = try allocator.create(verts_scene.buf_type);
    var iter = verts_scene.buf.iterator();
    while (iter.next()) |buf| {
        i = 0;
        while (i < cfg.gfx.depth_levels_max) : (i += 1) {
            buf.value_ptr.*.len[i] = 0;
        }
    }

    //--- Setup map ---//
    verts_map.vbo = try gfx_core.genBuffer();
    colors_map.vbo = try gfx_core.genBuffer();
    const map_n = map.getSizeX() * map.getSizeY();
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, verts_map.vbo,
                                         map_n * 8, .Dynamic);
    try gfx_core.bindVBOAndReserveBuffer(u32, .Array, colors_map.vbo,
                                         map_n * 4, .Dynamic);
    verts_map.buf = try allocator.alloc(f32, map_n * 8);
    colors_map.buf = try allocator.alloc(u32, map_n * 4);

    //--- Setup rays ---//
    verts_rays.vbo = try gfx_core.genBuffer();
    colors_rays.vbo = try gfx_core.genBuffer();
    try gfx_core.bindVBOAndReserveBuffer(f32, .Array, verts_rays.vbo, verts_rays.buf_size, .Dynamic);
    try gfx_core.bindVBOAndReserveBuffer(u32, .Array, colors_rays.vbo, colors_rays.buf_size, .Dynamic);
    verts_rays.buf = try allocator.create(verts_rays.buf_type);
    colors_rays.buf = try allocator.create(colors_rays.buf_type);

    // Framebuffer for scene
    fb_scene = try gfx_core.createFramebuffer(cfg.gfx.scene_fbo_size_x_max, cfg.gfx.scene_fbo_size_y_max);
    updateFramebufferSize(gfx_core.getWindowWidth(), gfx_core.getWindowHeight());
    {
        fb_sim = try gfx_core.createFramebuffer(1024, 1024);

        const v_buf =  try allocator.create(verts_scene.buf_type);
        i = 0;
        while (i < cfg.gfx.depth_levels_max) : (i += 1) {
            v_buf.len[i] = 0;
        }
        try verts_scene.buf.put(fb_sim.tex, v_buf);
    }
    // Framebuffer for map
    {
        const v_buf =  try allocator.create(verts_scene.buf_type);
        i = 0;
        while (i < cfg.gfx.depth_levels_max) : (i += 1) {
            v_buf.len[i] = 0;
        }
        fb_map = try gfx_core.createFramebuffer(cfg.map.fb_w, cfg.map.fb_h);
        try verts_scene.buf.put(fb_map.tex, v_buf);
    }
}

pub fn deinit() void {
    deleteBuffers() catch |e| {
        log_gfx.err("Error deleting OpenGL buffers: {}", .{e});
    };
    // try gfx_core.deleteShaderProgram(shader_program_base);
    // try gfx_core.deleteShaderProgram(shader_program_scene);
    // try gfx_core.deleteShaderProgram(shader_program_fullscreen);

    var iter = verts_scene.buf.valueIterator();
    while (iter.next()) |value| {
        allocator.destroy(value.*);
    }
    verts_scene.buf.deinit();
    // allocator.destroy(colors_scene.buf);
    allocator.free(colors_map.buf);
    allocator.free(verts_map.buf);
    allocator.destroy(colors_rays.buf);
    allocator.destroy(verts_rays.buf);

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

pub fn initShaders() !void {
    log_gfx.info("Processing shaders", .{});

    shader_program_base = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "pxy_f32_crgba_u32_base.vert",
        cfg.gfx.shader_dir ++ "pxy_crgba_f32_base.frag");
    shader_program_fullscreen = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "fullscreen.vert",
        cfg.gfx.shader_dir ++ "fullscreen.frag");
    shader_program_scene = try gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "scene.vert",
        cfg.gfx.shader_dir ++ "scene.frag");
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn getMapFboTexture() u32 {
    return fb_map.tex;
}

pub inline fn getSimFboTexture() u32 {
    return fb_sim.tex;
}

// var map_size_x: u32 = 10;
// var map_size_y: u32 = 10;

// pub fn setMapSize(x: u32, y: u32) !void {
//     if (x * y > map_size_x * map_size_y) {
//         try gfx_core.bindVBOAndReserveBuffer(u32, .Array, colors_map.vbo, x * y * 4, .Dynamic);
//         try gfx_core.bindVBOAndReserveBuffer(f32, .Array, verts_map.vbo, x * y * 8, .Dynamic);
//         colors_map.buf = try allocator.realloc(colors_map.buf, x * y * 4);
//         verts_map.buf = try allocator.realloc(verts_map.buf, x * y * 8);
//         log_gfx.debug("Map size changed, allocating new buffers and VBOs: ({},{}) -> ({},{})",
//                       .{map_size_x, map_size_y, x, y});
//     }
//     map_size_x = x;
//     map_size_y = y;
// }

//-----------------------------------------------------------------------------//
//   Fill render pipeline
//-----------------------------------------------------------------------------//

pub fn addLine(x0: f32, y0: f32, x1: f32, y1: f32, col: u32) void {
    const i = verts_rays.buf_n;
    const br = verts_rays.buf;
    br[i   ] = x0;
    br[i+1 ] = y0;
    br[i+2 ] = x1;
    br[i+3 ] = y1;
    verts_rays.buf_n += 4;
    const ic = colors_rays.buf_n;
    const bc = colors_rays.buf;
    bc[ic  ] = col;
    bc[ic+1] = col;
    colors_rays.buf_n += 2;
}

pub fn addQuad(x0: f32, y0: f32, x1: f32, y1: f32, col: u32) void {
    const i = verts_map.buf_n;
    const bd = verts_map.buf;
    bd[i  ] = x0;
    bd[i+1] = y0;
    bd[i+2] = x1;
    bd[i+3] = y0;
    bd[i+4] = x1;
    bd[i+5] = y1;
    bd[i+6] = x0;
    bd[i+7] = y1;
    verts_map.buf_n += 8;
    const ic = colors_map.buf_n;
    const bc = colors_map.buf;
    bc[ic  ] = col;
    bc[ic+1] = col;
    bc[ic+2] = col;
    bc[ic+3] = col;
    colors_map.buf_n += 4;
}

pub fn addQuadBackground(x0: f32, x1: f32, y0: f32, y1: f32, g0: f32, g1: f32) void {
    const i = verts_bg.buf_n;
    const bd = &verts_bg.buf;
    bd[i   ] = x0;
    bd[i+1 ] = y0;
    bd[i+2 ] = x1;
    bd[i+3 ] = y0;
    bd[i+4 ] = x1;
    bd[i+5 ] = y1;
    bd[i+6 ] = x0;
    bd[i+7 ] = y1;
    verts_bg.buf_n += 8;
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
                                h0: f32, h1: f32, ctr: f32, d0: u8, t: u32) void {
    // if (verts_scene.buf.contains(t)) {
    // Only test for tex id = 0, this is faster than the hashmap's "contains"
    if (t != 0) {
        const buf_t = verts_scene.buf.get(t).?;
        const i = buf_t.len[d0];
        const bd = &buf_t.data[d0];
        bd[i   ] = x0;
        bd[i+1 ] = y0;
        bd[i+2 ] = r;
        bd[i+3 ] = g;
        bd[i+4 ] = b;
        bd[i+5 ] = a;
        bd[i+6 ] = u_0;
        bd[i+7 ] = v0;
        bd[i+8 ] = h0;
        bd[i+9 ] = ctr;
        bd[i+10] = x1;
        bd[i+11] = y1;
        bd[i+12] = r;
        bd[i+13] = g;
        bd[i+14] = b;
        bd[i+15] = a;
        bd[i+16] = u_1;
        bd[i+17] = v0;
        bd[i+18] = h1;
        bd[i+19] = ctr;
        bd[i+20] = x1;
        bd[i+21] = y2;
        bd[i+22] = r;
        bd[i+23] = g;
        bd[i+24] = b;
        bd[i+25] = a;
        bd[i+26] = u_1;
        bd[i+27 ] = v1;
        bd[i+28] = h1;
        bd[i+29] = ctr;
        bd[i+30] = x0;
        bd[i+31] = y3;
        bd[i+32] = r;
        bd[i+33] = g;
        bd[i+34] = b;
        bd[i+35] = a;
        bd[i+36] = u_0;
        bd[i+37] = v1;
        bd[i+38] = h0;
        bd[i+39] = ctr;
        buf_t.len[d0] += 40;
    }
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn registerTexture(w: u32, h: u32, data: []u8) !u32 {
    const tex = try gfx_core.createTexture(w, h, data);
    const v_buf =  try allocator.create(verts_scene.buf_type);
    var i: u32 = 0;
    while (i < cfg.gfx.depth_levels_max) : (i += 1) {
        v_buf.len[i] = 0;
    }
    try verts_scene.buf.put(tex, v_buf);
    return tex;
}

pub fn reloadShaders() !void {
    log_gfx.info("Reloading shaders", .{});

    const sp_base = gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "base.vert",
        cfg.gfx.shader_dir ++ "base.frag") catch |e| {

        log_gfx.err("Error reloading shaders: {}", .{e});
        return;
    };

    const sp_fullscreen = gfx_core.createShaderProgramFromFiles(
        cfg.gfx.shader_dir ++ "fullscreen.vert",
        cfg.gfx.shader_dir ++ "fullscreen.frag") catch |e| {

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
    try gfx_core.deleteShaderProgram(shader_program_fullscreen);
    shader_program_fullscreen = sp_fullscreen;
    try gfx_core.deleteShaderProgram(shader_program_scene);
    shader_program_scene = sp_scene;

    // Reset all uniforms
    updateProjection(gfx_core.getWindowWidth(), gfx_core.getWindowHeight());
}

//-----------------------------------------------------------------------------//
//   Rendering
//-----------------------------------------------------------------------------//

pub fn renderFrame() !void {
    try gfx_core.disableGammaCorrectionFBO();

    // 1. Render to textures used in the scene
    try gfx_core.bindFBO(fb_sim.fbo);
    try gfx_core.clearFramebuffer();
    try renderSimOverlay();

    try gfx_core.bindFBO(fb_map.fbo);
    try gfx_core.clearFramebuffer();
    try renderMap();

    // 2. Render the scene (walls, floor, ceiling)
    try gfx_core.bindFBO(fb_scene.fbo);
    try gfx_core.clearFramebuffer();
    try renderScene();

    // 3. Render on screen
    try gfx_core.enableGammaCorrectionFBO();
    try gfx_core.bindFBO(0);
    try gfx_core.clearFramebuffer();

    try renderSceneToScreen();
}

fn renderFloorAndCeiling() !void {
    try gfx_core.bindVAO(vao_0);
    const w = @as(u32, @intFromFloat(@as(f32, @floatFromInt(gfx_core.getWindowWidth())) * cfg.gfx.scene_sampling_factor));
    const h = @as(u32, @intFromFloat(@as(f32, @floatFromInt(gfx_core.getWindowHeight())) * cfg.gfx.scene_sampling_factor));
    updateProjectionByShader(shader_program_base, w, -@as(i64, @intCast(h)));

    try gfx_core.setViewport(0, 0, w, h);
    try gfx_core.useShaderProgram(shader_program_base);
    try gfx_core.bindVBOAndBufferSubData(f32, 0, verts_bg.vbo, @intCast(verts_bg.buf_n), &verts_bg.buf);
    try gfx_core.enableVertexAttributes(0);
    try gfx_core.setupVertexAttributesFloat(0, 2, 0, 0);
    try gfx_core.bindVBOAndBufferSubData(u32, 0, colors_bg.vbo, @intCast(colors_bg.buf_n), &colors_bg.buf);
    try gfx_core.enableVertexAttributes(1);
    try gfx_core.setupVertexAttributesUInt32(1, 1, 0, 0);
    try gfx_core.disableVertexAttributes(2);
    try gfx_core.disableVertexAttributes(3);
    try gfx_core.bindEBO(ebo);
    try gfx_core.drawElements(.Triangles, @intCast(verts_bg.buf_n*6/8));
    verts_bg.buf_n = 0;
    colors_bg.buf_n = 0;
}

fn renderScene() !void {
    try renderFloorAndCeiling();

    try gfx_core.bindVAO(vao_0);
    try gfx_core.useShaderProgram(shader_program_scene);
    try gfx_core.setUniform1f(shader_program_scene, "u_center",
                              @as(f32, @floatFromInt(fb_scene.h_vp)) * 0.5);

    try gfx_core.bindVBO(verts_scene.vbo);
    try gfx_core.bindEBO(ebo);
    const s = try gfx_base.setVertexAttributes(.PxyCrgbaTuvH);

    var i: u32 = cfg.gfx.depth_levels_max;
    while (i > 1) : (i -= 1) {
        var iter = verts_scene.buf.iterator();
        while (iter.next()) |tex| {
            if (tex.value_ptr.*.len[i-1] > 0) {
                try gfx_core.bindVBOAndBufferSubData(f32, 0, verts_scene.vbo, @intCast(tex.value_ptr.*.len[i-1]),
                                                     &(tex.value_ptr.*.data[i-1]));
                try gfx_core.bindTexture(tex.key_ptr.*);

                // Draw based on indices.
                try gfx_core.drawElements(.Triangles, @intCast(tex.value_ptr.*.len[i-1]*6/(4*s)));

                tex.value_ptr.*.len[i-1] = 0;
            }
        }
    }
}

fn renderSceneToScreen() !void {
    try gfx_core.bindVAO(vao_0);
    _ = try gfx_base.setVertexAttributes(.PxyTuvCuniF32);
    try gfx_core.setViewportFull();
    try gfx_core.useShaderProgram(shader_program_fullscreen);
    try gfx_core.bindTexture(fb_scene.tex);
    try gfx_core.drawArrays(.Triangles, 0, 3);
}

fn renderMap() !void {
    try gfx_core.bindVAO(vao_0);
    //--- Map ---//
    updateProjectionByShader(shader_program_base, fb_map.w, fb_map.h);
    try gfx_core.setViewport(0, 0, fb_map.w, fb_map.h);

    try gfx_core.bindVBOAndBufferSubData(f32, 0, verts_map.vbo, @intCast(verts_map.buf_n), verts_map.buf);
    try gfx_core.enableVertexAttributes(0);
    try gfx_core.setupVertexAttributesFloat(0, 2, 0, 0);
    try gfx_core.bindVBOAndBufferSubData(u32, 0, colors_map.vbo, @intCast(colors_map.buf_n), colors_map.buf);
    try gfx_core.enableVertexAttributes(1);
    try gfx_core.setupVertexAttributesUInt32(1, 1, 0, 0);
    try gfx_core.disableVertexAttributes(2);
    try gfx_core.disableVertexAttributes(3);
    try gfx_core.bindEBO(ebo);
    try gfx_core.drawElements(.Triangles, @intCast(verts_map.buf_n*6/8));
    verts_map.buf_n = 0;
    colors_map.buf_n = 0;

    //--- Rays ---//
    try gfx_core.bindVBOAndBufferSubData(f32, 0, verts_rays.vbo, verts_rays.buf_n, verts_rays.buf);
    try gfx_core.enableVertexAttributes(0);
    try gfx_core.setupVertexAttributesFloat(0, 2, 0, 0);
    try gfx_core.bindVBOAndBufferSubData(u32, 0, colors_rays.vbo, @intCast(colors_rays.buf_n), colors_rays.buf);
    try gfx_core.enableVertexAttributes(1);
    try gfx_core.setupVertexAttributesUInt32(1, 1, 0, 0);
    try gfx_core.drawArrays(.Lines, 0, @intCast(verts_rays.buf_n / 2));
    colors_rays.buf_n = 0;
    verts_rays.buf_n = 0;
}

fn renderSimOverlay() !void {
    if (sim.is_map_displayed) {
        {
            gfx_base.updateProjection(.PxyTuvCuniF32Font, 0, @floatFromInt(fb_sim.w_vp - 1), 0,
                                      @floatFromInt(fb_sim.h_vp - 1));
        }
        try gfx_core.setViewport(0, 0, fb_sim.w_vp, fb_sim.h_vp);
        try fnt.setFont("anka_b", 32);
        try fnt.renderText("Gravity simulation, 10000 asteroids", 10, 10, 0.0, 1.0, 0.1, 0.0, 0.6);
        {
            gfx_base.updateProjection(.PxyCrgbaF32, 0, @floatFromInt(gfx_core.getWindowWidth() - 1), 0,
                                      @floatFromInt(gfx_core.getWindowHeight() - 1));
        }
        try gfx_core.setPointSize(2);
        try gfx_base.renderBatch(sim.getBufferIdDebris(), .Points, .Update);
        try gfx_core.setPointSize(1);
        try gfx_base.renderBatch(sim.getBufferIdPlanet(), .TriangleFan, .Update);
        {
            gfx_base.updateProjection(.PxyTuvCuniF32, 0, @floatFromInt(gfx_core.getWindowWidth() - 1),
                                      @floatFromInt(gfx_core.getWindowHeight() - 1), 0);
            gfx_base.updateProjection(.PxyTuvCuniF32Font, 0, @floatFromInt(gfx_core.getWindowWidth() - 1),
                                      @floatFromInt(gfx_core.getWindowHeight() - 1), 0);
        }
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx = std.log.scoped(.gfx_rw);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var shader_program_base: u32 = 0;
var shader_program_fullscreen: u32 = 0;
var shader_program_scene: u32 = 0;
var ebo: u32 = 0;
var vao_0: u32 = 0;
var fb_map: gfx_core.fb_data = undefined;
var fb_scene: gfx_core.fb_data = undefined;
var fb_sim: gfx_core.fb_data = undefined;

const colors_bg = struct {
    const buf_size = 16;
    const buf_type = [colors_bg.buf_size]u32;

    var buf: buf_type = undefined;
    var buf_n: u32 = 0;
    var vbo: u32 = 0;
};

const verts_bg = struct {
    const buf_size = 32;
    const buf_type = [buf_size]f32;

    var buf: buf_type = undefined;
    var buf_n: u32 = 0;
    var vbo: u32 = 0;
};

const colors_map = struct {
    var buf: []u32 = undefined;
    var buf_n: u32 = 0;
    var vbo: u32 = 0;
};

const verts_map = struct {
    var buf: []f32 = undefined;
    var buf_n: u32 = 0;
    var vbo: u32 = 0;
};

const verts_scene = struct {
    const attrib_size = 40;
    const buf_size = 4096*2*verts_scene.attrib_size;
    const buf_type = struct {
        data: [cfg.gfx.depth_levels_max][verts_scene.buf_size]f32 = undefined,
        len: [cfg.gfx.depth_levels_max]u32 = undefined
    };

    var buf = std.AutoHashMap(u32, *buf_type).init(allocator);
    var vbo: u32 = 0;
};

const colors_rays = struct {
    const buf_size = 4096*2*cfg.rc.segments_max;
    const buf_type = [colors_rays.buf_size]u32;

    var buf: *colors_rays.buf_type = undefined;
    var buf_n: u32 = 0;
    var vbo: u32 = 0;
};

const verts_rays = struct {
    const buf_size = 4096*2*2*cfg.rc.segments_max;
    const buf_type = [verts_rays.buf_size]f32;

    var buf: *verts_rays.buf_type = undefined;
    var buf_n: u32 = 0;
    var vbo: u32 = 0;
};


fn handleWindowResize(w: u32, h: u32) void {
    const w_s = @as(u32, @intFromFloat(@as(f32, @floatFromInt(w)) * cfg.gfx.scene_sampling_factor));
    const h_s = @as(u32, @intFromFloat(@as(f32, @floatFromInt(h)) * cfg.gfx.scene_sampling_factor));
    updateProjection(w_s, h_s);
    updateFramebufferSize(w, h);

    log_gfx.debug("Window resize callback triggered, w = {}, h = {}", .{w, h});
}

fn updateFramebufferSize(w: u32, h: u32) void {
    fb_scene.w_vp = @as(u32, @intFromFloat(@as(f32, @floatFromInt(w)) * cfg.gfx.scene_sampling_factor));
    fb_scene.h_vp = @as(u32, @intFromFloat(@as(f32, @floatFromInt(h)) * cfg.gfx.scene_sampling_factor));
    const scale_x = @as(f32, @floatFromInt(fb_scene.w_vp)) / cfg.gfx.scene_fbo_size_x_max;
    const scale_y = @as(f32, @floatFromInt(fb_scene.h_vp)) / cfg.gfx.scene_fbo_size_y_max;
    gfx_core.setUniform1f(shader_program_fullscreen, "u_tex_scale_x", scale_x ) catch |e| {
        log_gfx.err("Couldn't set uniform u_tex_scale_x: {}", .{e});
    };
    gfx_core.setUniform1f(shader_program_fullscreen, "u_tex_scale_y", scale_y ) catch |e| {
        log_gfx.err("Couldn't set uniform u_tex_scale_y: {}", .{e});
    };
}

fn updateProjection(w: i64, h: i64) void {
    // Adjust projection for vertex shader
    // (simple ortho projection, therefore, no explicit matrix)
    updateProjectionByShader(shader_program_base, w, h);
    updateProjectionByShader(shader_program_scene, w, h);
}

fn updateProjectionByShader(sp: u32, w: i64, h: i64) void {
    const o_w = @as(f32, @floatFromInt(w)) * 0.5;
    const o_h = @as(f32, @floatFromInt(h)) * 0.5;
    const w_r = 1.0 / o_w;
    const h_r = 1.0 / o_h;
    gfx_core.setUniform4f(sp, "t", w_r, h_r, o_w, @abs(o_h)) catch |e| {
        log_gfx.err("{}", .{e});
    };
}

//-----------------------------------------------------------------------------//
//   Clean up
//-----------------------------------------------------------------------------//

fn deleteBuffers() !void {
    try gfx_core.deleteBuffer(vao_0);
    try gfx_core.deleteBuffer(ebo);
    try gfx_core.deleteBuffer(colors_bg.vbo);
    try gfx_core.deleteBuffer(verts_bg.vbo);
    try gfx_core.deleteBuffer(verts_scene.vbo);
    // try gfx_core.deleteBuffer(colors_scene.vbo);
    try gfx_core.deleteBuffer(colors_map.vbo);
    try gfx_core.deleteBuffer(verts_map.vbo);
    try gfx_core.deleteBuffer(colors_rays.vbo);
    try gfx_core.deleteBuffer(verts_rays.vbo);
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//
