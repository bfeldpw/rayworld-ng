const std = @import("std");
const cfg = @import("config.zig");
// const gfx = @import("graphics.zig"); const gfx_impl = @import("gfx_impl.zig");
const gfx_core = @import("gfx_core.zig");
const gfx_base = @import("gfx_base.zig");
const gfx_rw = @import("gfx_rw.zig");
const map = @import("map.zig"); const stats = @import("stats.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    log_ray.debug("Allocating memory for ray data", .{});

    try allocMemory(640);

    if (cfg.multithreading) {
        cpus = try std.Thread.getCpuCount();
        if (cpus > cfg.rc.threads_max) cpus = cfg.rc.threads_max;
        log_ray.info("Utilising {} logical cpu cores for multithreading", .{cpus});
    }
}

pub fn deinit() void {
    freeMemory();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_ray.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn createMap() !void {
    const m = map.get();
    const map_cells_y = @as(f32, map.get().len);
    const win_h: f32 = @floatFromInt(gfx_core.getWindowHeight());
    const f = win_h * cfg.rc.map_display_height / map_cells_y; // scale factor cell -> px
    const o = win_h - f * map_cells_y; // y-offset for map drawing in px

    for (m, 0..) |y, j| {
        for (y, 0..) |cell, i| {
            const c = map.getColor(j, i);
            switch (cell) {
                .floor => {
                    gfx_rw.addQuad(@as(f32, @floatFromInt(i)) * f,
                             o + @as(f32, @floatFromInt(j)) * f,
                             @as(f32, @floatFromInt(i + 1)) * f,
                             o + @as(f32, @floatFromInt(j + 1)) * f,
                             gfx_core.compressColor(c.r, c.g, c.b, cfg.rc.map_display_opacity));
                },
                .wall, .wall_thin, .mirror, .glass, .pillar, .pillar_glass => {
                    gfx_rw.addQuad(@as(f32, @floatFromInt(i)) * f,
                             o + @as(f32, @floatFromInt(j)) * f,
                             @as(f32, @floatFromInt(i + 1)) * f,
                             o + @as(f32, @floatFromInt(j + 1)) * f,
                             gfx_core.compressColor(
                             0 + 0.1 * c.r,
                             0 + 0.1 * c.g,
                             0 + 0.1 * c.b,
                             cfg.rc.map_display_opacity));
                },
            }
        }
    }

    var i: usize = 0;
    while (i < rays.seg_i0.len) : (i += 1) {
        if (i % cfg.rc.map_display_every_nth_line == 0) {
            var j: i32 = @intCast(rays.seg_i1[i]);
            const j0: i32 = @intCast(rays.seg_i0[i]);

            if (j - j0 > cfg.rc.map_display_reflections_max) {
                j = j0 + cfg.rc.map_display_reflections_max;
            }
            // const color_step = 1.0 / @as(f32, cfg.rc.map_display_reflections_max + 1);

            while (j >= j0) : (j -= 1) {
                // const color_grade = color_step * @as(f32, @floatFromInt(j-j0));
                const k: usize = @intCast(j);
                if (j == j0) {
                    gfx_rw.addLine(segments.x0[k] * f,
                                o + segments.y0[k] * f,
                                segments.x1[k] * f,
                                o + segments.y1[k] * f,
                                gfx_core.compressColor(0.0, 0.0, 1.0, 0.1));
                } else {
                    gfx_rw.addLine(segments.x0[k] * f,
                                o + segments.y0[k] * f,
                                segments.x1[k] * f,
                                o + segments.y1[k] * f,
                                gfx_core.compressColor(0.0, 0.75, 1.0, 0.05/@as(f32, @floatFromInt(j-j0))));
                }
            }
        }
    }

    const x = plr.getPosX();
    const y = plr.getPosY();
    const w = 0.1;
    const h = 0.5;
    const d = plr.getDir();
    try gfx_base.addVertexPxyCrgba((x - w * @sin(d)) * f, o + (y + w * @cos(d)) * f,
                                    0.0, 0.7, 0.0, 1.0);
    try gfx_base.addVertexPxyCrgba((x + h * @cos(d)) * f, o + (y + h * @sin(d)) * f,
                                    0.0, 0.7, 0.0, 1.0);
    try gfx_base.addVertexPxyCrgba((x + w * @sin(d)) * f, o + (y - w * @cos(d)) * f,
                                    0.0, 0.7, 0.0, 1.0);
}

pub fn createScene() void {
    const win_h: f32 = @floatFromInt(gfx_core.getWindowHeight());
    const tilt = -win_h * plr.getTilt();

    gfx_rw.addQuadBackground(0, @floatFromInt(gfx_core.getWindowWidth()), tilt - win_h, tilt, 0.8, 0.5);
    gfx_rw.addQuadBackground(0, @floatFromInt(gfx_core.getWindowWidth()), tilt, tilt + win_h * 0.5, 0.5, 0.05);
    gfx_rw.addQuadBackground(0, @floatFromInt(gfx_core.getWindowWidth()), tilt + win_h * 0.5, tilt + win_h, 0.05, 0.2);
    gfx_rw.addQuadBackground(0, @floatFromInt(gfx_core.getWindowWidth()), tilt + win_h, tilt + 2 * win_h, 0.2, 0.4);

    var i: usize = 0;

    const depth_levels = cfg.gfx.depth_levels_max;
    const Previous = struct {
        cell_type: map.CellType,
        m_x: usize,
        m_y: usize,
        u_of_uv: f32,
        tex_id: u32,
        x: f32,
        y0: f32,
        y0_cvs: f32,
        y1: f32,
        y1_cvs: f32,
    };
    var previous: [depth_levels]Previous = undefined;

    for (&previous) |*value| {
        value.m_x = 0;
        value.m_y = 0;
        value.tex_id = 0;
    }

    while (i < rays.seg_i0.len) : (i += 1) {
        const x = @as(f32, @floatFromInt(i)) * cfg.sub_sampling_base;
        const j0 = rays.seg_i0[i];
        const j1 = rays.seg_i1[i];
        var j = j1;

        // Angle between current ray and player direction
        const ang_0 = (@as(f32, @floatFromInt(i)) /
                       @as(f32, @floatFromInt(rays.seg_i0.len)) - 0.5) * plr.getFOV();

        while (j >= j0) : (j -= 1) {

            const k = @as(usize, j);
            const sub_sampling = segments.sub_sample_level[k];
            const depth_layer: u8 = @intCast(j - j0 + 1);

            if (i % sub_sampling == 0) {

                // Use an optical pleasing combination of the natural lense effect due
                // to a "point" camera and the "straight line correction". This results
                // in little dynamic changes when rotating the camera (instead of just)
                // moving the still scene on the screen) as well as the non-linearity
                // that differentiates it from polygons.
                // Note: Even when using the cosine, walls are not perfectly straight, since
                // angular resolution becomes non-constant, especially for large FOVs
                var d = segments.d[k];
                d *= (0.5 + 0.5 * @cos(ang_0));

                // Restrict minimum distance, i.e. maximum height drawn
                if (d < 0.5) d = 0.5;
                var d_norm = 2 / d; // At 2m distance, the walls are screen filling (w.r.t. height)
                const h_half = win_h * d_norm * 0.5;

                // For colours, do not increase d_norm too much for distances < 2m,
                // since colors become white, otherwise
                if (d_norm > 1) d_norm = 1;

                shift_and_tilt = win_h * plr.getPosZ() / (d + 1e-3) + tilt;
                const m_x = segments.cell_x[k];
                const m_y = segments.cell_y[k];
                const cell_type = segments.cell_type[k];

                var prev = &previous[depth_layer];

                // Flat shading component on a per-ray basis
                const col_amb: f32 = cfg.gfx.ambient_normal_shading;
                var col_norm: f32 = col_amb;
                var u_of_uv: f32 = 0;
                if (cell_type != .pillar and cell_type != .pillar_glass) {
                    if (segments.contact_axis[k] == .x) {
                        u_of_uv = segments.x1[k] - @trunc(segments.x1[k]);
                        col_norm += (1.0 - col_amb) * @abs(@sin(ang_0 + plr.getDir()));
                        if (segments.y0[k] < segments.y1[k]) {
                            u_of_uv = 1 - u_of_uv;
                        }
                    } else {
                        u_of_uv = segments.y1[k] - @trunc(segments.y1[k]);
                        col_norm += (1.0 - col_amb) * @abs(@cos(ang_0 + plr.getDir()));
                        if (segments.x0[k] > segments.x1[k]) {
                            u_of_uv = 1 - u_of_uv;
                        }
                    }
                } else {
                    // Flat shading for pillars
                    const p_x = segments.x1[k] - @as(f32, @floatFromInt(m_x));
                    const p_y = segments.y1[k] - @as(f32, @floatFromInt(m_y));
                    // Norm vector:
                    const n_x = p_x - map.getPillar(m_y, m_x).center_x;
                    const n_y = p_y - map.getPillar(m_y, m_x).center_y;
                    // Colliding ray vector:
                    const r_x= segments.x1[k] - segments.x0[k];
                    const r_y= segments.y1[k] - segments.y0[k];

                    var ang_n = std.math.atan2(f32, n_y, n_x);
                    if (ang_n < 0) ang_n += 2.0 * std.math.pi;
                    if (ang_n > 2.0 * std.math.pi) ang_n -= 2.0 * std.math.pi;
                    var ang_r = std.math.atan2(f32, r_y, r_x);
                    if (ang_r < 0) ang_r += 2.0 * std.math.pi;
                    if (ang_r > 2.0 * std.math.pi) ang_r -= 2.0 * std.math.pi;
                    const circ = 2.0 * std.math.pi;
                    u_of_uv = 1.0 - ang_n / circ;
                    col_norm += (1.0 - col_amb) * @abs(@cos(ang_n - ang_r));
                }

                const col = map.getColor(m_y, m_x);

                const col_shading = std.math.pow(f32, std.math.clamp(d_norm, 0.0, 1.0), 1.7) * col_norm;
                const canvas = map.getCanvas(m_y, m_x);
                const canvas_col = map.getCanvasColor(m_y, m_x);
                const tex_id = map.getTextureID(m_y, m_x).id;

                const h_half_top = h_half * @mulAdd(f32, -2, canvas.top, 1); // h_half*(1-2*canvas_top);
                const h_half_bottom = h_half * @mulAdd(f32, -2, canvas.bottom, 1); // h_half*(1-2*canvas_bottom);

                // From canvas top to top to bottom to canvas bottom
                var y0_cvs = win_h * 0.5 - h_half + shift_and_tilt;
                var y0 = win_h * 0.5 - h_half_top + shift_and_tilt;
                var y1 = win_h * 0.5 + h_half_bottom + shift_and_tilt;
                var y1_cvs = win_h * 0.5 + h_half + shift_and_tilt;

                // Height for SSAO calculation in shaders
                var h_ssao = y1_cvs - y0_cvs;

                // Handle special cases of subsampling
                var is_new = true;
                const abs_x = @abs(@as(i16, @intCast(m_x)) - @as(i16, @intCast(prev.m_x)));
                const abs_y = @abs(@as(i16, @intCast(m_y)) - @as(i16, @intCast(prev.m_y)));
                const axis = segments.contact_axis[k];
                if (axis == .x and abs_x < 2 and m_y == prev.m_y) is_new = false;
                if (axis == .y and abs_y < 2 and m_x == prev.m_x) is_new = false;
                if ((m_x != prev.m_x or m_y != prev.m_y) and
                    (cell_type == .wall_thin and prev.cell_type == .wall_thin)) is_new = true;
                if (prev.cell_type != cell_type) is_new = true;
                if (prev.tex_id != tex_id) is_new = true;

                if (is_new) prev.x = x - @as(f32, @floatFromInt(sub_sampling)) * cfg.sub_sampling_base;
                if (cfg.sub_sampling_blocky or is_new) {
                    prev.u_of_uv = u_of_uv;
                    prev.y0_cvs = y0_cvs;
                    prev.y0 = y0;
                    prev.y1_cvs = y1_cvs;
                    prev.y1 = y1;
                }

                if (tex_id != 0) {
                    gfx_rw.addVerticalTexturedQuadY(prev.x, x, prev.y0, y0, y1, prev.y1, prev.u_of_uv, u_of_uv, 0, 1,
                                                 col_shading * col.r,
                                                 col_shading * col.g,
                                                 col_shading * col.b, col.a,
                                                 h_ssao, shift_and_tilt, depth_layer, tex_id);
                } else {
                    // gfx_rw.addVerticalQuadY(prev.x, x, prev.y0, y0, y1, prev.y1,
                    //                      col_shading * col.r,
                    //                      col_shading * col.g,
                    //                      col_shading * col.b, col.a,
                    //                      h_ssao, shift_and_tilt, depth_layer);
                    gfx_rw.addVerticalTexturedQuadY(prev.x, x, prev.y0, y0, y1, prev.y1, 0, 0, 0, 0,
                                         col_shading * col.r,
                                         col_shading * col.g,
                                         col_shading * col.b, col.a,
                                            h_ssao, shift_and_tilt, depth_layer, 0);
                }
                if (canvas.bottom + canvas.top > 0.0) {
                    if (canvas.tex_id != 0) {
                        gfx_rw.addVerticalTexturedQuadY(prev.x, x, prev.y0_cvs, y0_cvs, y0, prev.y0, prev.u_of_uv, u_of_uv, 0, canvas.top,
                                                     col_shading * canvas_col.r,
                                                     col_shading * canvas_col.g,
                                                     col_shading * canvas_col.b, canvas_col.a,
                                                     h_ssao, shift_and_tilt, depth_layer, canvas.tex_id);
                        gfx_rw.addVerticalTexturedQuadY(prev.x, x, prev.y1_cvs, y1_cvs, y1, prev.y1, prev.u_of_uv, u_of_uv, 1, 1 - canvas.bottom,
                                                     col_shading * canvas_col.r,
                                                     col_shading * canvas_col.g,
                                                     col_shading * canvas_col.b, canvas_col.a,
                                                     h_ssao, shift_and_tilt, depth_layer, canvas.tex_id);
                    } else {
                        // gfx_rw.addVerticalQuadY(prev.x, x, prev.y0_cvs, y0_cvs, y0, prev.y0,
                        //                     col_shading * canvas_col.r,
                        //                     col_shading * canvas_col.g,
                        //                     col_shading * canvas_col.b, canvas_col.a,
                        //                     h_ssao, shift_and_tilt, depth_layer);
                        // gfx_rw.addVerticalQuadY(prev.x, x, prev.y1_cvs, y1_cvs, y1, prev.y1,
                        //                     col_shading * canvas_col.r,
                        //                     col_shading * canvas_col.g,
                        //                     col_shading * canvas_col.b, canvas_col.a,
                        //                     h_ssao, shift_and_tilt, depth_layer);
                    }
                }
                prev.cell_type = cell_type;
                prev.m_x = m_x;
                prev.m_y = m_y;
                prev.tex_id = tex_id;
                prev.x = x;
                if (!cfg.sub_sampling_blocky) {
                    prev.u_of_uv = u_of_uv;
                    prev.y0_cvs = y0_cvs;
                    prev.y0 = y0;
                    prev.y1 = y1;
                    prev.y1_cvs = y1_cvs;
                }
                if (j == j0) {
                    break;
                }
            }
        }
    }
}

pub fn processRays(comptime multithreading: bool) !void {
    try reallocRaysOnChange();

    var angle: f32 = @mulAdd(f32, -0.5, plr.getFOV(), plr.getDir());
    const inc_angle: f32 = plr.getFOV() / @as(f32, @floatFromInt(rays.seg_i0.len));

    const split = rays.seg_i0.len / cpus;

    if (multithreading) {
        var cpu: u8 = 0;
        while (cpu < cpus) : (cpu += 1) {
            var last = (cpu + 1) * split;
            if (cpu == cpus - 1) last = rays.seg_i0.len;
            threads[cpu] = try std.Thread.spawn(.{}, traceMultipleRays, .{ cpu * split, last, @mulAdd(f32, inc_angle, @floatFromInt(cpu * split), angle), inc_angle });
        }
        cpu = 0;
        while (cpu < cpus) : (cpu += 1) {
            threads[cpu].join();
        }
    } else {
        traceMultipleRays(0, rays.seg_i0.len, angle, inc_angle);
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const segments_max = cfg.rc.segments_max;

const log_ray = std.log.scoped(.ray);

var cpus: usize = 4;
var threads: [cfg.rc.threads_max]std.Thread = undefined;

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var shift_and_tilt: f32 = 0;

/// Struct of arrays (SOA) to store ray data
const RayData = struct {
    seg_i0: []usize,
    seg_i1: []usize,
};

/// Struct of arrays (SOA) to store data of ray segments
const RaySegmentData = struct {
    x0: []f32,
    y0: []f32,
    x1: []f32,
    y1: []f32,
    d: []f32,
    contact_axis: []Axis,
    sub_sample_level: []u8,
    cell_type: []map.CellType,
    cell_x: []usize,
    cell_y: []usize,
};

/// Struct of array instanciation to store ray data. Memory allocation is done
/// in @init function
var rays = RayData{
    .seg_i0 = undefined,
    .seg_i1 = undefined,
};

/// Struct of array instanciation to store ray segment data. Memory allocation is
/// done in @init function
var segments = RaySegmentData{
    .x0 = undefined,
    .y0 = undefined,
    .x1 = undefined,
    .y1 = undefined,
    .d = undefined,
    .contact_axis = undefined,
    .sub_sample_level = undefined,
    .cell_type = undefined,
    .cell_x = undefined,
    .cell_y = undefined,
};

fn allocMemory(n: usize) !void {
    // Allocate for memory for ray data
    rays.seg_i0 = allocator.alloc(usize, n) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(rays.seg_i0);
    rays.seg_i1 = allocator.alloc(usize, n) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(rays.seg_i1);

    const s = cfg.rc.segments_splits_max;

    // Allocate memory for segment data
    segments.x0 = allocator.alloc(f32, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.x0);
    segments.y0 = allocator.alloc(f32, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.y0);
    segments.x1 = allocator.alloc(f32, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.x1);
    segments.y1 = allocator.alloc(f32, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.y1);
    segments.d = allocator.alloc(f32, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.d);
    segments.contact_axis = allocator.alloc(Axis, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.contact_axis);
    segments.sub_sample_level = allocator.alloc(u8, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.sub_sample_level);
    segments.cell_type = allocator.alloc(map.CellType, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.cell_type);
    segments.cell_x = allocator.alloc(usize, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.cell_x);
    segments.cell_y = allocator.alloc(usize, n * s * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.cell_y);
}

fn freeMemory() void {
    allocator.free(rays.seg_i0);
    allocator.free(rays.seg_i1);
    allocator.free(segments.x0);
    allocator.free(segments.y0);
    allocator.free(segments.x1);
    allocator.free(segments.y1);
    allocator.free(segments.d);
    allocator.free(segments.contact_axis);
    allocator.free(segments.sub_sample_level);
    allocator.free(segments.cell_type);
    allocator.free(segments.cell_x);
    allocator.free(segments.cell_y);
}

fn reallocRaysOnChange() !void {
    if (gfx_core.getWindowWidth() / cfg.sub_sampling_base != rays.seg_i0.len) {
        log_ray.debug("Reallocating memory for ray data", .{});

        freeMemory();
        try allocMemory(gfx_core.getWindowWidth() / cfg.sub_sampling_base);

        log_ray.debug("Window resized, changing number of initial rays -> {}", .{rays.seg_i0.len});
    }
}

fn traceMultipleRays(i_0: usize, i_1: usize, angle_0: f32, inc: f32) void {
    const p_x = plr.getPosX();
    const p_y = plr.getPosY();

    var i = i_0;
    var angle = angle_0;

    while (i < i_1) {
        const j = segments_max * i;
        rays.seg_i0[i] = j;
        rays.seg_i1[i] = j;
        segments.x0[j] = p_x;
        segments.y0[j] = p_y;
        segments.sub_sample_level[j] = 1;

        traceSingleSegment(angle, j, i);

        i += 1;
        angle += inc;
    }
}

inline fn traceSingleSegment(angle: f32, s_i: usize, r_i: usize) void {
    var d_x = @cos(angle); // direction x
    var d_y = @sin(angle); // direction y
    traceSingleSegment0(d_x, d_y, s_i, r_i, .floor, 1.0, segments_max - 1);
}

const Axis = enum { x, y };

const ContactStatus = struct {
    finish_segment: bool,
    prepare_next_segment: bool,
    reflection_limit: i8,
    cell_type_prev: map.CellType,
};

fn traceSingleSegment0(d_x0: f32, d_y0: f32, s_i: usize, r_i: usize, c_prev: map.CellType, n_prev: f32, refl_lim: i8) void {
    var s_x = segments.x0[s_i]; // segment pos x
    var s_y = segments.y0[s_i]; // segment pos y
    var d_x = d_x0; // direction x
    var d_y = d_y0; // direction y
    const g_x = d_y / d_x; // gradient/derivative of the segment for direction x
    const g_y = d_x / d_y; // gradient/derivative of the segment for direction y

    var sign_x: f32 = 1;
    var sign_y: f32 = 1;

    var a: Axis = .y; // primary axis for stepping
    if (@abs(d_x) > @abs(d_y)) a = .x;
    if (d_x < 0) sign_x = -1;
    if (d_y < 0) sign_y = -1;

    var material_index_prev = n_prev;

    var contact_status: ContactStatus = .{ .finish_segment = false, .prepare_next_segment = true, .reflection_limit = 0, .cell_type_prev = c_prev };

    while (!contact_status.finish_segment) {
        var o_x: f32 = 0;
        var o_y: f32 = 0;
        var contact_axis: Axis = .x;

        advanceToNextCell(&d_x, &d_y, &s_x, &s_y, &o_x, &o_y, &sign_x, &sign_y, &a, &contact_axis, g_x, g_y);

        var m_y: usize = @intFromFloat(s_y + o_y);
        var m_x: usize = @intFromFloat(s_x + o_x);
        if (m_y > map.get().len - 1) m_y = map.get().len - 1;
        if (m_x > map.get()[0].len - 1) m_x = map.get()[0].len - 1;
        const m_v = map.get()[m_y][m_x];

        // React to cell type
        switch (m_v) {
            .floor => {
                if (map.get()[@intFromFloat(plr.getPosY())][@intFromFloat(plr.getPosX())] == .wall_thin) {
                // if (contact_status.cell_type_prev == .wall_thin) {
                    contact_status = resolveContactWallThin(&d_x, &d_y, &s_x, &s_y, m_x, m_y,
                                                            r_i, &contact_axis, refl_lim, d_x0, d_y0);
                } else {
                    contact_status = resolveContactFloor(&d_x, &d_y, &material_index_prev, contact_status.cell_type_prev, m_x, m_y, contact_axis, refl_lim, d_x0, d_y0);
                }
            },
            .wall => {
                contact_status = resolveContactWall(&d_x, &d_y, m_x, m_y, r_i, contact_axis, refl_lim, d_x0, d_y0);
            },
            .wall_thin => {
                contact_status = resolveContactWallThin(&d_x, &d_y, &s_x, &s_y, m_x, m_y,
                                                        r_i, &contact_axis, refl_lim, d_x0, d_y0);
            },
            .mirror => {
                contact_status = resolveContactMirror(&d_x, &d_y, m_x, m_y, r_i, contact_axis, refl_lim, d_x0, d_y0);
            },
            .glass => {
                contact_status = resolveContactGlass(&d_x, &d_y, &material_index_prev, m_x, m_y, contact_axis, refl_lim, d_x0, d_y0);
            },
            .pillar => {
                contact_status = resolveContactPillar(&d_x, &d_y, &s_x, &s_y, m_x, m_y, m_v, refl_lim, d_x0, d_y0, s_i, r_i);
            },
            .pillar_glass => {
                contact_status = resolveContactPillarGlass(&d_x, &d_y, &s_x, &s_y, m_x, m_y, m_v, refl_lim, d_x0, d_y0, s_i, r_i);
            },
        }

        proceedPostContact(contact_status, contact_axis, m_x, m_y, m_v, c_prev, material_index_prev, s_i, r_i, s_x, s_y, d_x, d_y);
    }
}

inline fn advanceToNextCell(d_x: *f32, d_y: *f32, s_x: *f32, s_y: *f32, o_x: *f32, o_y: *f32, sign_x: *f32, sign_y: *f32, axis: *Axis, contact_axis: *Axis, g_x: f32, g_y: f32) void {
    if (sign_x.* == 1) {
        d_x.* = @trunc(s_x.* + 1) - s_x.*;
    } else {
        d_x.* = @ceil(s_x.* - 1) - s_x.*;
    }
    if (sign_y.* == 1) {
        d_y.* = @trunc(s_y.* + 1) - s_y.*;
    } else {
        d_y.* = @ceil(s_y.* - 1) - s_y.*;
    }

    if (axis.* == .x) {
        if (@abs(d_x.* * g_x) < @abs(d_y.*)) {
            s_x.* += d_x.*;
            s_y.* += @abs(d_x.* * g_x) * sign_y.*;
            if (sign_x.* == -1) o_x.* = -0.5;
            contact_axis.* = .y;
        } else {
            s_x.* += @abs(d_y.* * g_y) * sign_x.*;
            s_y.* += d_y.*;
            if (sign_y.* == -1) o_y.* = -0.5;
            contact_axis.* = .x;
        }
    } else { // (axis.* == .y)
        if (@abs(d_y.* * g_y) < @abs(d_x.*)) {
            s_x.* += @abs(d_y.* * g_y) * sign_x.*;
            s_y.* += d_y.*;
            if (sign_y.* == -1) o_y.* = -0.5;
            contact_axis.* = .x;
        } else {
            s_x.* += d_x.*;
            s_y.* += @abs(d_x.* * g_x) * sign_y.*;
            if (sign_x.* == -1) o_x.* = -0.5;
            contact_axis.* = .y;
        }
    }
}

inline fn resolveContactFloor(d_x: *f32, d_y: *f32, n_prev: *f32, cell_type_prev: map.CellType,
                              m_x: usize, m_y: usize, contact_axis: Axis, refl_lim: i8,
                              d_x0: f32, d_y0: f32) ContactStatus {
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);
    var ctp = cell_type_prev;
    if (cell_type_prev == .glass) {
        n_prev.* = map.getGlass(m_y, m_x).n;
        const n = 1.0 / n_prev.*;
        const refl = std.math.asin(@as(f32, n));
        if (contact_axis == .x) {
            const alpha = std.math.atan2(f32, @abs(d_x0), @abs(d_y0));
            // total inner reflection?
            if (alpha > refl) {
                d_y.* = -d_y0;
                d_x.* = d_x0;
                ctp = .glass;
            } else {
                // const beta = std.math.asin(@sin(alpha) / n);
                // ...
                // d_x.* = @sin(beta);
                // This can be optimised a little:
                const beta_x = @sin(alpha) / n;
                const beta_y = std.math.asin(beta_x);
                d_x.* = beta_x;
                d_y.* = @cos(beta_y);
                if (d_x0 < 0) d_x.* = -d_x.*;
                if (d_y0 < 0) d_y.* = -d_y.*;
                ctp = .floor;
            }
        } else { // contact_axis == .y
            const alpha = std.math.atan2(f32, @abs(d_y0), @abs(d_x0));
            // total inner reflection?
            if (alpha > refl) {
                d_y.* = d_y0;
                d_x.* = -d_x0;
                ctp = .glass;
            } else {
                // const beta = std.math.asin(@sin(alpha) / n);
                // ...
                // d_y.* = @sin(beta);
                // This can be optimised a little:
                const beta_y = @sin(alpha) / n;
                const beta_x = std.math.asin(beta_y);
                d_y.* = beta_y;
                d_x.* = @cos(beta_x);
                if (d_x0 < 0) d_x.* = -d_x.*;
                if (d_y0 < 0) d_y.* = -d_y.*;
                ctp = .floor;
            }
        }
        return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = ctp };
    } else {
        ctp = .floor;
        n_prev.* = 1.0;
        return .{ .finish_segment = false, .prepare_next_segment = false, .reflection_limit = r_lim, .cell_type_prev = ctp };
    }
}

inline fn resolveContactWall(d_x: *f32, d_y: *f32, m_x: usize, m_y: usize, r_i: usize, contact_axis: Axis, refl_lim: i8, d_x0: f32, d_y0: f32) ContactStatus {
    const hsh = std.hash.Murmur3_32;
    var scatter = 1.0 - 2.0 * @as(f32, @floatFromInt(hsh.hashUint32(@intCast(r_i)))) / std.math.maxInt(u32);
    const scatter_f = map.getReflection(m_y, m_x).diffusion;
    if (contact_axis == .x) {
        d_y.* = -d_y0;
        d_x.* = d_x0 + scatter * scatter_f;
    } else {
        d_x.* = -d_x0;
        d_y.* = d_y0 + scatter * scatter_f;
    }
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);

    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall };
}

inline fn resolveContactWallThin(d_x: *f32, d_y: *f32, s_x: *f32, s_y: *f32, m_x: usize, m_y: usize, r_i: usize, contact_axis: *Axis, refl_lim: i8, d_x0: f32, d_y0: f32) ContactStatus {
    const hsh = std.hash.Murmur3_32;
    var scatter = 1.0 - 2.0 * @as(f32, @floatFromInt(hsh.hashUint32(@intCast(r_i)))) / std.math.maxInt(u32);
    const scatter_f = map.getReflection(m_y, m_x).diffusion;
    const axis = map.getWallThin(m_y, m_x).axis;
    const from = map.getWallThin(m_y, m_x).from;
    const to = map.getWallThin(m_y, m_x).to;
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);
    if (axis == .x) {
        if (contact_axis.* == .y) {
            // c_y: contact on y-axis at cell border
            // s_y is always positive (coordinate on map)
            const c_y = s_y.* - @trunc(s_y.*);
            if (c_y >= from and c_y <= to) {
                d_x.* = -d_x0;
                d_y.* = d_y0 + scatter * scatter_f;
                return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
            } else if (c_y < from and d_y0 > 0.0) {
                // c_yw: contact y on wall within cell
                const c_yw = (from - c_y) * d_x0 / d_y0;
                if (@abs(c_yw) >= 0.0 and @abs(c_yw) <= 1.0) {
                    s_x.* += c_yw;
                    s_y.* += from - c_y;
                    d_x.* = d_x0 + scatter * scatter_f;
                    d_y.* = -d_y0;
                    contact_axis.* = .x;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            } else if (c_y > to and d_y0 < 0.0) {
                // c_yw: contact y on wall within cell
                const c_yw = (c_y - to) * d_x0 / d_y0;
                if (@abs(c_yw) >= 0.0 and @abs(c_yw) <= 1.0) {
                    s_x.* -= c_yw;
                    s_y.* -= c_y - to;
                    d_x.* = d_x0 + scatter * scatter_f;
                    d_y.* = -d_y0;
                    contact_axis.* = .x;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            }
        } else { // if (contact_axis.* == .x) {
            // c_x: contact on x-axis at cell border
            // s_x is always positive (coordinate on map)
            const c_x = s_x.* - @trunc(s_x.*);
            if (d_y0 > 0.0) {
                const c_xw = c_x + from * d_x0 / d_y0;
                if (c_xw >= 0.0 and c_xw <= 1.0) {
                    s_x.* += from * d_x0 / d_y0;
                    s_y.* += from;
                    d_x.* = d_x0 + scatter * scatter_f;
                    d_y.* = -d_y0;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            } else if (d_y0 < 0.0) {
                const c_xw = c_x - (1.0 - to) * d_x0 / d_y0;
                if (c_xw >= 0.0 and c_xw <= 1.0) {
                    s_x.* -= (1.0 - to) * d_x0 / d_y0;
                    s_y.* -= 1.0 - to;
                    d_x.* = d_x0 + scatter * scatter_f;
                    d_y.* = -d_y0;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            }
        }
    } else { // if (axis == .y) {
        if (contact_axis.* == .x) {
            // c_x: contact on x-axis at cell border
            // s_x is always positive (coordinate on map)
            const c_x = s_x.* - @trunc(s_x.*);
            if (c_x >= from and c_x <= to) {
                d_x.* = d_x0 + scatter * scatter_f;
                d_y.* = -d_y0;
                return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
            } else if (c_x < from and d_x0 > 0.0) {
                // c_xw: contact x on wall within cell
                const c_xw = (from - c_x) * d_y0 / d_x0;
                if (@abs(c_xw) >= 0.0 and @abs(c_xw) <= 1.0) {
                    s_x.* += from - c_x;
                    s_y.* += c_xw;
                    d_x.* = -d_x0;
                    d_y.* = d_y0 + scatter * scatter_f;
                    contact_axis.* = .y;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            } else if (c_x > to and d_x0 < 0.0) {
                // c_xw: contact x on wall within cell
                const c_xw = (c_x - to) * d_y0 / d_x0;
                if (@abs(c_xw) >= 0.0 and @abs(c_xw) <= 1.0) {
                    s_x.* -= c_x - to;
                    s_y.* -= c_xw;
                    d_x.* = -d_x0;
                    d_y.* = d_y0 + scatter * scatter_f;
                    contact_axis.* = .y;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            }
        } else { // if (contact_axis.* == .y) {
            // c_y: contact on x-axis at cell border
            // s_y is always positive (coordinate on map)
            const c_y = s_y.* - @trunc(s_y.*);
            if (d_x0 > 0.0) {
                const c_yw = c_y + from * d_y0 / d_x0;
                if (c_yw >= 0.0 and c_yw <= 1.0) {
                    s_x.* += from;
                    s_y.* += from * d_y0 / d_x0;
                    d_x.* = -d_x0;
                    d_y.* = d_y0 + scatter * scatter_f;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            } else if (d_x0 < 0.0) {
                const c_yw = c_y - (1.0 - to) * d_y0 / d_x0;
                if (c_yw >= 0.0 and c_yw <= 1.0) {
                    s_x.* -= 1.0 - to;
                    s_y.* -= (1.0 - to) * d_y0 / d_x0;
                    d_x.* = -d_x0;
                    d_y.* = d_y0 + scatter * scatter_f;
                    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
                }
            }
        }
    }
    // Default: nothing's hit, pass through
    return .{ .finish_segment = false, .prepare_next_segment = false, .reflection_limit = r_lim - 1, .cell_type_prev = .wall_thin };
}

inline fn resolveContactMirror(d_x: *f32, d_y: *f32, m_x: usize, m_y: usize, r_i: usize, contact_axis: Axis, refl_lim: i8, d_x0: f32, d_y0: f32) ContactStatus {
    const hsh = std.hash.Murmur3_32;
    var scatter = 1.0 - 2.0 * @as(f32, @floatFromInt(hsh.hashUint32(@intCast(r_i)))) / std.math.maxInt(u32);
    const scatter_f = map.getReflection(m_y, m_x).diffusion;
    if (contact_axis == .x) {
        d_y.* = -d_y0;
        d_x.* = d_x0 + scatter * scatter_f;
    } else {
        d_x.* = -d_x0;
        d_y.* = d_y0 + scatter * scatter_f;
    }

    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);

    return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .mirror };
}

inline fn resolveContactGlass(d_x: *f32, d_y: *f32, n_prev: *f32, m_x: usize, m_y: usize, contact_axis: Axis, refl_lim: i8, d_x0: f32, d_y0: f32) ContactStatus {
    const n = map.getGlass(m_y, m_x).n / n_prev.*;
    n_prev.* = map.getGlass(m_y, m_x).n;

    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);

    if (n != 1.0) {
        if (contact_axis == .x) {
            const alpha = std.math.atan2(f32, @abs(d_x0), @abs(d_y0));
            const r = @sin(alpha) / n;
            if (r > 1.0) {
                d_x.* =  d_x0;
                d_y.* = -d_y0;
            } else {
                const beta = std.math.asin(r);
                d_x.* = r;
                d_y.* = @cos(beta);
                if (d_x0 < 0) d_x.* = -d_x.*;
                if (d_y0 < 0) d_y.* = -d_y.*;
            }
        } else { // contact_axis == .y
            const alpha = std.math.atan2(f32, @abs(d_y0), @abs(d_x0));
            const r = @sin(alpha) / n;
            if (r > 1.0) {
                d_x.* = -d_x0;
                d_y.* =  d_y0;
            } else {
                const beta = std.math.asin(r);
                d_y.* = r;
                d_x.* = @cos(beta);
                if (d_x0 < 0) d_x.* = -d_x.*;
                if (d_y0 < 0) d_y.* = -d_y.*;
            }
        }
        return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .glass };
    } else {
        return .{ .finish_segment = false, .prepare_next_segment = false, .reflection_limit = r_lim, .cell_type_prev = .glass };
    }
}

inline fn resolveContactPillar(d_x: *f32, d_y: *f32, s_x: *f32, s_y: *f32, m_x: usize, m_y: usize, m_v: map.CellType, refl_lim: i8, d_x0: f32, d_y0: f32, s_i: usize, r_i: usize) ContactStatus {
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);
    const pillar = map.getPillar(m_y, m_x);
    const e_x = @as(f32, @floatFromInt(m_x)) + pillar.center_x - s_x.*;
    const e_y = @as(f32, @floatFromInt(m_y)) + pillar.center_y - s_y.*;
    const e_norm_sqr = e_x * e_x + e_y * e_y;
    const c_a = e_x * d_x0 + d_y0 * e_y;
    const r = pillar.radius;
    const w = r * r - (e_norm_sqr - c_a * c_a);
    if (w >= 0) {
        const d_p = c_a - @sqrt(w);
        if (d_p >= 0) {
            segments.d[s_i] = d_p;
            segments.cell_x[s_i] = m_x;
            segments.cell_y[s_i] = m_y;
            segments.cell_type[s_i] = m_v;

            segments.x1[s_i] = s_x.* + d_x0 * d_p;
            segments.y1[s_i] = s_y.* + d_y0 * d_p;

            const r_x = (d_x0 * d_p - e_x) / r;
            const r_y = (d_y0 * d_p - e_y) / r;
            d_x.* = 2 * (-e_x * r_x - e_y * r_y) * r_x - d_x0 * d_p;
            d_y.* = 2 * (-e_x * r_x - e_y * r_y) * r_y - d_y0 * d_p;

            const s_x0 = segments.x0[s_i];
            const s_y0 = segments.y0[s_i];
            const s_dx = s_x.* - s_x0;
            const s_dy = s_y.* - s_y0;
            // Accumulate distances, if first segment, set
            if (s_i > rays.seg_i0[r_i]) {
                segments.d[s_i] = segments.d[s_i - 1] + @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            } else {
                segments.d[s_i] = @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            }

            s_x.* += d_x0 * d_p;
            s_y.* += d_y0 * d_p;

            return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .pillar };
        }
    }
    return .{ .finish_segment = false, .prepare_next_segment = false, .reflection_limit = r_lim, .cell_type_prev = .pillar };
}

inline fn resolveContactPillarGlass(d_x: *f32, d_y: *f32, s_x: *f32, s_y: *f32,
                                    m_x: usize, m_y: usize, m_v: map.CellType,
                                    refl_lim: i8, d_x0: f32, d_y0: f32,
                                    s_i: usize, r_i: usize) ContactStatus {
    const n = map.getGlass(m_y, m_x).n;
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);
    const pillar = map.getPillar(m_y, m_x);
    const e_x = @as(f32, @floatFromInt(m_x)) + pillar.center_x - s_x.*;
    const e_y = @as(f32, @floatFromInt(m_y)) + pillar.center_y - s_y.*;
    const e_norm_sqr = e_x * e_x + e_y * e_y;
    const c_a = e_x * d_x0 + d_y0 * e_y;
    const r = pillar.radius;
    const w = r * r - (e_norm_sqr - c_a * c_a);
    if (w >= 0) {
        const d_p = c_a - @sqrt(w);
        if (d_p >= 0) {
            segments.d[s_i] = d_p;
            segments.cell_x[s_i] = m_x;
            segments.cell_y[s_i] = m_y;
            segments.cell_type[s_i] = m_v;

            segments.x1[s_i] = s_x.* + d_x0 * d_p;
            segments.y1[s_i] = s_y.* + d_y0 * d_p;

            var alpha = std.math.atan2(f32, d_y0, d_x0) -
                        std.math.atan2(f32, d_y0 * d_p - pillar.center_y,
                                            d_x0 * d_p - pillar.center_x);
                        // std.math.atan2(f32, d_y0 * d_p - @intToFloat(f32, m_y) + pillar.center_y,
                        //                     d_x0 * d_p - @intToFloat(f32, m_x) + pillar.center_x);
            // if (alpha >  std.math.pi) alpha -= 2.0 * std.math.pi;
            // if (alpha < -std.math.pi) alpha += 2.0 * std.math.pi;
            const beta = alpha / n;
            d_y.* = @sin(beta);
            d_x.* = @cos(beta);

            // const r_x = (d_x0 * d_p - e_x) / r;
            // const r_y = (d_y0 * d_p - e_y) / r;
            // d_x.* = 2 * (-e_x * r_x - e_y * r_y) * r_x - d_x0 * d_p;
            // d_y.* = 2 * (-e_x * r_x - e_y * r_y) * r_y - d_y0 * d_p;

            const s_x0 = segments.x0[s_i];
            const s_y0 = segments.y0[s_i];
            const s_dx = s_x.* - s_x0;
            const s_dy = s_y.* - s_y0;
            // Accumulate distances, if first segment, set
            if (s_i > rays.seg_i0[r_i]) {
                segments.d[s_i] = segments.d[s_i - 1] + @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            } else {
                segments.d[s_i] = @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            }

            s_x.* += d_x0 * d_p;
            s_y.* += d_y0 * d_p;

            return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .pillar_glass };
        }
    }
    return .{ .finish_segment = false, .prepare_next_segment = false, .reflection_limit = r_lim, .cell_type_prev = .pillar };
}

inline fn proceedPostContact(contact_status: ContactStatus, contact_axis: Axis, m_x: usize, m_y: usize, m_v: map.CellType, c_prev: map.CellType, n_prev: f32, s_i: usize, r_i: usize, s_x: f32, s_y: f32, d_x: f32, d_y: f32) void {
    segments.contact_axis[s_i] = contact_axis;

    // if there is any kind of contact and a the segment ends, save all
    // common data
    if (contact_status.finish_segment == true and m_v != .pillar and m_v != .pillar_glass) {
        if (c_prev == .glass and m_v == .floor) {
            segments.cell_x[s_i] = segments.cell_x[s_i - 1];
            segments.cell_y[s_i] = segments.cell_y[s_i - 1];
            segments.cell_type[s_i] = segments.cell_type[s_i - 1];
        } else {
            segments.cell_x[s_i] = m_x;
            segments.cell_y[s_i] = m_y;
            segments.cell_type[s_i] = m_v;
        }
        segments.x1[s_i] = s_x;
        segments.y1[s_i] = s_y;
        const s_x0 = segments.x0[s_i];
        const s_y0 = segments.y0[s_i];
        const s_dx = s_x - s_x0;
        const s_dy = s_y - s_y0;

        // Accumulate distances, if first segment, set
        if (s_i > rays.seg_i0[r_i]) {
            segments.d[s_i] = segments.d[s_i - 1] + @sqrt(s_dx * s_dx + s_dy * s_dy);
        } else {
            segments.d[s_i] = @sqrt(s_dx * s_dx + s_dy * s_dy);
        }
    }
    // Prepare next segment
    // Only prepare next segment if not already the last segment of the
    // last ray!
    if (contact_status.prepare_next_segment and s_i + 1 < rays.seg_i0.len * segments_max) {
        // Just be sure to stay below the maximum segment number per ray
        // if ((rays.seg_i1[r_i] - rays.seg_i0[r_i]) < contact_status.reflection_limit) {
        const refl = contact_status.reflection_limit + 1;
        if (refl > 0) {
            const subs = map.getReflection(m_y, m_x).sub_sampling;
            if (r_i % subs == 0) {
                segments.x0[s_i + 1] = s_x;
                segments.y0[s_i + 1] = s_y;
                segments.sub_sample_level[s_i + 1] = segments.sub_sample_level[s_i] * subs;
                rays.seg_i1[r_i] += 1;
                traceSingleSegment0(d_x, d_y, s_i + 1, r_i, contact_status.cell_type_prev, n_prev, contact_status.reflection_limit);
            }
        }
    }
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "raycaster: init/deinit" {
    // try gfx.init();
    try init();
    try map.init();
    // defer gfx_.deinit();
    defer deinit();
    defer map.deinit();
    // try processRays(false);
}
