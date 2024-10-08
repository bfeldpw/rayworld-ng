const std = @import("std");
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");
const gfx_base = @import("gfx_base.zig");
const gfx_rw = @import("gfx_rw.zig");
const map = @import("map.zig");
const stats = @import("stats.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//
pub fn init() !void {
    log_ray.debug("Allocating memory for ray data", .{});

    try resizeDataStructures(640);

    if (cfg.multithreading) {
        cpus = try std.Thread.getCpuCount();
        if (cpus > cfg.rc.threads_max) cpus = cfg.rc.threads_max;

        try std.Thread.Pool.init(&thread_pool, .{.allocator = allocator, .n_jobs = @intCast(cpus)});
        cpus = thread_pool.threads.len;
        log_ray.info("Utilising {} logical cpu cores for multithreading", .{cpus});
    }
}

pub fn deinit() void {
    thread_pool.deinit();
    freeMemory();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_ray.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn createMap() !void {
    const m = map.get();
    const scale_x = @as(f32, cfg.map.fb_w) / map.getSizeX();
    const scale_y = @as(f32, cfg.map.fb_h) / map.getSizeY();

    for (m, 0..) |y, j| {
        for (y, 0..) |cell, i| {
            const c = map.getColor(j, i);
            switch (cell) {
                .floor => {
                    gfx_rw.addQuad(@as(f32, @floatFromInt(i)) * scale_x,
                                   @as(f32, @floatFromInt(j)) * scale_y,
                                   @as(f32, @floatFromInt(i + 1)) * scale_x,
                                   @as(f32, @floatFromInt(j + 1)) * scale_y,
                                   gfx_core.compressColor(c.r, c.g, c.b, 1.0));
                },
                .wall, .wall_thin, .mirror, .glass, .pillar, .pillar_glass => {
                    gfx_rw.addQuad(@as(f32, @floatFromInt(i)) * scale_x,
                                   @as(f32, @floatFromInt(j)) * scale_y,
                                   @as(f32, @floatFromInt(i + 1)) * scale_x,
                                   @as(f32, @floatFromInt(j + 1)) * scale_y,
                                   gfx_core.compressColor(
                                       0 + 0.1 * c.r,
                                       0 + 0.1 * c.g,
                                       0 + 0.1 * c.b, 1.0));
                },
            }
        }
    }

    var i: usize = 0;
    while (i < rays.items.len) : (i += 1) {
        if (i % cfg.rc.map_display_every_nth_line == 0) {
            var j: i32 = @intCast(rays.items[i].seg_i1);
            const j0: i32 = @intCast(rays.items[i].seg_i0);

            if (j - j0 > cfg.rc.map_display_reflections_max) {
                j = j0 + cfg.rc.map_display_reflections_max;
            }

            while (j >= j0) : (j -= 1) {
                const k: usize = @intCast(j);
                if (j == j0) {
                    gfx_rw.addLine(segments.pos.items[k].x0 * scale_x,
                                   segments.pos.items[k].y0 * scale_y,
                                   segments.pos.items[k].x1 * scale_x,
                                   segments.pos.items[k].y1 * scale_y,
                                   gfx_core.compressColor(0.0, 0.0, 1.0, 0.1));
                } else {
                    gfx_rw.addLine(segments.pos.items[k].x0 * scale_x,
                                   segments.pos.items[k].y0 * scale_y,
                                   segments.pos.items[k].x1 * scale_x,
                                   segments.pos.items[k].y1 * scale_y,
                                   gfx_core.compressColor(0.0, 0.75, 1.0, 0.05/@as(f32, @floatFromInt(j-j0))));
                }
            }
        }
    }

    const x = plr.getPosX();
    _ = x;
    const y = plr.getPosY();
    _ = y;
    const w = 0.1;
    _ = w;
    const h = 0.5;
    _ = h;
    const d = plr.getDir();
    _ = d;
    // var data = try gfx_base.getBufferToAddVertexData(0, 18);
    // data.ptr[0] = 21;
    // data.ptr[1] = 22;

    // var data = [18]f32 {(x - w * @sin(d)) * f, o + (y + w * @cos(d)) * f,
    //                      0.0, 0.7, 0.0, 1.0,
    //                     (x + h * @cos(d)) * f, o + (y + h * @sin(d)) * f,
    //                      0.0, 0.7, 0.0, 1.0,
    //                     (x + w * @sin(d)) * f, o + (y - w * @cos(d)) * f,
    //                      0.0, 0.7, 0.0, 1.0};
    // try gfx_base.addVertexData(0, &data);
}

pub fn createScene() void {
    const win_h  = @as(f32, @floatFromInt(gfx_core.getWindowHeight())) * cfg.gfx.scene_sampling_factor;
    const win_w  = @as(f32, @floatFromInt(gfx_core.getWindowWidth())) * cfg.gfx.scene_sampling_factor;
    const tilt = -win_h * plr.getTilt();

    gfx_rw.addQuadBackground(0, win_w, tilt - win_h, tilt, 0.8, 0.5);
    gfx_rw.addQuadBackground(0, win_w, tilt, tilt + win_h * 0.5, 0.5, 0.05);
    gfx_rw.addQuadBackground(0, win_w, tilt + win_h * 0.5, tilt + win_h, 0.05, 0.2);
    gfx_rw.addQuadBackground(0, win_w, tilt + win_h, tilt + 2 * win_h, 0.2, 0.4);

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
        h_ssao: f32
    };
    var previous: [depth_levels]Previous = undefined;

    for (&previous) |*value| {
        value.m_x = 0;
        value.m_y = 0;
        value.u_of_uv = 0;
        value.tex_id = 0;
    }

    while (i < rays.items.len) : (i += 1) {
        const x = @as(f32, @floatFromInt(i+1)) * cfg.gfx.scene_sampling_factor * @as(f32 ,@floatFromInt(cfg.sub_sampling_base));
        const j0 = rays.items[i].seg_i0;
        const j1 = rays.items[i].seg_i1;
        var j = j1;

        // Angle between current ray and player direction
        const ang_0 = (@as(f32, @floatFromInt(i)) /
                       @as(f32, @floatFromInt(rays.items.len)) - 0.5) * plr.getFOV();

        while (j >= j0) : (j -= 1) {

            const k = @as(usize, j);
            const sub_sampling = segments.sub_sample_level.items[k];
            const depth_layer: u8 = @intCast(j - j0 + 1);

            if (i % sub_sampling == 0) {

                // Use an optical pleasing combination of the natural lense effect due
                // to a "point" camera and the "straight line correction". This results
                // in little dynamic changes when rotating the camera (instead of just)
                // moving the still scene on the screen) as well as the non-linearity
                // that differentiates it from polygons.
                // Note: Even when using the cosine, walls are not perfectly straight, since
                // angular resolution becomes non-constant, especially for large FOVs
                var d = segments.d.items[k];
                d *= (0.5 + 0.5 * @cos(ang_0));

                // Restrict minimum distance, i.e. maximum height drawn
                if (d < 0.5) d = 0.5;
                var d_norm = 2 / d; // At 2m distance, the walls are screen filling (w.r.t. height)
                const h_half = win_h * d_norm * 0.5;

                // For colours, do not increase d_norm too much for distances < 2m,
                // since colors become white, otherwise
                if (d_norm > 1) d_norm = 1;

                shift_and_tilt = win_h * plr.getPosZ() / (d + 1e-3) + tilt;
                const m_x = segments.cell.items[k].x;
                const m_y = segments.cell.items[k].y;
                const cell_type = segments.cell.items[k].t;

                var prev = &previous[depth_layer];

                // Flat shading component on a per-ray basis
                const col_amb: f32 = cfg.gfx.ambient_normal_shading;
                var col_norm: f32 = col_amb;
                var u_of_uv: f32 = 0;
                if (cell_type != .pillar and cell_type != .pillar_glass) {
                    if (segments.cell.items[k].contact_axis == .x) {
                        u_of_uv = segments.pos.items[k].x1 - @trunc(segments.pos.items[k].x1);
                        col_norm += (1.0 - col_amb) * @abs(@sin(ang_0 + plr.getDir()));
                        if (segments.pos.items[k].y0 < segments.pos.items[k].y1) {
                            u_of_uv = 1 - u_of_uv;
                        }
                    } else {
                        u_of_uv = segments.pos.items[k].y1 - @trunc(segments.pos.items[k].y1);
                        col_norm += (1.0 - col_amb) * @abs(@cos(ang_0 + plr.getDir()));
                        if (segments.pos.items[k].x0 > segments.pos.items[k].x1) {
                            u_of_uv = 1 - u_of_uv;
                        }
                    }
                } else {
                    // Flat shading for pillars
                    const p_x = segments.pos.items[k].x1 - @as(f32, @floatFromInt(m_x));
                    const p_y = segments.pos.items[k].y1 - @as(f32, @floatFromInt(m_y));
                    // Norm vector:
                    const n_x = p_x - map.getPillar(m_y, m_x).center_x;
                    const n_y = p_y - map.getPillar(m_y, m_x).center_y;
                    // Colliding ray vector:
                    const r_x= segments.pos.items[k].x1 - segments.pos.items[k].x0;
                    const r_y= segments.pos.items[k].y1 - segments.pos.items[k].y0;

                    var ang_n = std.math.atan2(n_y, n_x);
                    if (ang_n < 0) ang_n += 2.0 * std.math.pi;
                    if (ang_n > 2.0 * std.math.pi) ang_n -= 2.0 * std.math.pi;
                    var ang_r = std.math.atan2(r_y, r_x);
                    if (ang_r < 0) ang_r += 2.0 * std.math.pi;
                    if (ang_r > 2.0 * std.math.pi) ang_r -= 2.0 * std.math.pi;
                    const circ = 2.0 * std.math.pi;
                    u_of_uv = 1.0 - ang_n / circ;
                    col_norm += (1.0 - col_amb) * @abs(@cos(ang_n - ang_r));
                }

                const col = map.getColor(m_y, m_x);

                const col_shading = std.math.pow(f32, std.math.clamp(d_norm, 0.0, 1.0), 1.5) * col_norm;
                const canvas = map.getCanvas(m_y, m_x);
                const canvas_col = map.getCanvasColor(m_y, m_x);
                const tex_id = map.getTextureID(m_y, m_x).id;

                const h_half_top = h_half * @mulAdd(f32, -2, canvas.top, 1); // h_half*(1-2*canvas_top);
                const h_half_bottom = h_half * @mulAdd(f32, -2, canvas.bottom, 1); // h_half*(1-2*canvas_bottom);

                // From canvas top to top to bottom to canvas bottom
                const y0_cvs = win_h * 0.5 - h_half + shift_and_tilt;
                const y0 = win_h * 0.5 - h_half_top + shift_and_tilt;
                const y1 = win_h * 0.5 + h_half_bottom + shift_and_tilt;
                const y1_cvs = win_h * 0.5 + h_half + shift_and_tilt;

                // Height for SSAO calculation in shaders
                const h_ssao = y1_cvs - y0_cvs;

                // Handle special cases of subsampling
                var is_new = true;
                const abs_x = @abs(@as(i16, @intCast(m_x)) - @as(i16, @intCast(prev.m_x)));
                const abs_y = @abs(@as(i16, @intCast(m_y)) - @as(i16, @intCast(prev.m_y)));
                const axis = segments.cell.items[k].contact_axis;
                if (axis == .x and abs_x < 2 and m_y == prev.m_y) is_new = false;
                if (axis == .y and abs_y < 2 and m_x == prev.m_x) is_new = false;
                if ((m_x != prev.m_x or m_y != prev.m_y) and
                    (cell_type == .wall_thin and prev.cell_type == .wall_thin)) is_new = true;
                if (prev.cell_type != cell_type) is_new = true;
                if (prev.tex_id != tex_id) is_new = true;

                if (is_new) prev.x = x - @as(f32, @floatFromInt(sub_sampling)) * cfg.gfx.scene_sampling_factor
                                                                               * @as(f32, @floatFromInt(cfg.sub_sampling_base));
                if (cfg.sub_sampling_blocky or is_new) {
                    prev.u_of_uv = 0; //u_of_uv;
                    prev.y0_cvs = y0_cvs;
                    prev.y0 = y0;
                    prev.y1_cvs = y1_cvs;
                    prev.y1 = y1;
                    prev.h_ssao = h_ssao;
                }

                if (tex_id != 0) {
                    gfx_rw.addVerticalTexturedQuadY(prev.x, x, prev.y0, y0, y1, prev.y1, prev.u_of_uv, u_of_uv, 0, 1,
                                                    @min(col_shading * col.r, col.r),
                                                    @min(col_shading * col.g, col.g),
                                                    @min(col_shading * col.b, col.b),
                                                    col.a,
                                                    prev.h_ssao, h_ssao, shift_and_tilt, depth_layer, tex_id);
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
                                                    prev.h_ssao, h_ssao, shift_and_tilt, depth_layer, 0);
                }
                if (canvas.bottom + canvas.top > 0.0) {
                    if (canvas.tex_id != 0) {
                        gfx_rw.addVerticalTexturedQuadY(prev.x, x, prev.y0_cvs, y0_cvs, y0, prev.y0, prev.u_of_uv, u_of_uv, 0, canvas.top,
                                                     col_shading * canvas_col.r,
                                                     col_shading * canvas_col.g,
                                                     col_shading * canvas_col.b, canvas_col.a,
                                                     prev.h_ssao, h_ssao, shift_and_tilt, depth_layer, canvas.tex_id);
                        gfx_rw.addVerticalTexturedQuadY(prev.x, x, prev.y1_cvs, y1_cvs, y1, prev.y1, prev.u_of_uv, u_of_uv, 1, 1 - canvas.bottom,
                                                     col_shading * canvas_col.r,
                                                     col_shading * canvas_col.g,
                                                     col_shading * canvas_col.b, canvas_col.a,
                                                     prev.h_ssao, h_ssao, shift_and_tilt, depth_layer, canvas.tex_id);
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
                prev.u_of_uv = u_of_uv;
                prev.h_ssao = h_ssao;
                if (!cfg.sub_sampling_blocky) {
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

    const angle: f32 = @mulAdd(f32, -0.5, plr.getFOV(), plr.getDir());
    const inc_angle: f32 = plr.getFOV() / @as(f32, @floatFromInt(rays.items.len));

    const split = rays.items.len / cpus;

    if (multithreading) {
        var cpu: u8 = 0;
        while (cpu < cpus) : (cpu += 1) {
            var last = (cpu + 1) * split;
            if (cpu == cpus - 1) last = rays.items.len;
            thread_group_rays.start();

            try std.Thread.Pool.spawn(&thread_pool, traceMultipleRays, .{ cpu * split, last, @mulAdd(f32, inc_angle, @floatFromInt(cpu * split), angle), inc_angle });
        }
        while (!thread_group_rays.isDone()) std.time.sleep(1000);
        thread_group_rays.reset();
    } else {
        traceMultipleRays(0, rays.items.len, angle, inc_angle);
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const segments_max = cfg.rc.segments_max;

const log_ray = std.log.scoped(.ray);

var cpus: usize = 4;
var thread_pool: std.Thread.Pool = undefined;
var thread_group_rays: std.Thread.WaitGroup = .{};

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var shift_and_tilt: f32 = 0;

/// Struct of arrays (SOA) to store ray data
const RayData = struct {
    seg_i0: usize,
    seg_i1: usize,
};

const PosData = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32
};

const CellData = struct {
    x: usize,
    y: usize,
    t: map.CellType,
    contact_axis: Axis
};

/// Struct of arrays (SOA) to store data of ray segments
const RaySegmentData = struct {
    pos: std.ArrayList(PosData),
    cell: std.ArrayList(CellData),
    sub_sample_level: std.ArrayList(u8),
    d: std.ArrayList(f32)
};

// const FloorSegmentData = struct {
//     pos: std.ArrayList(PosData),
//     tex_id: u32
// };

/// Struct of array instanciation to store ray data. Memory allocation is done
/// in @init function
var rays = std.ArrayList(RayData).init(allocator);

/// Struct of array instanciation to store ray segment data. Memory allocation is
/// done in @init function
var segments = RaySegmentData{
    .pos = std.ArrayList(PosData).init(allocator),
    .cell = std.ArrayList(CellData).init(allocator),
    .sub_sample_level = std.ArrayList(u8).init(allocator),
    .d = std.ArrayList(f32).init(allocator),
};

fn resizeDataStructures(n: usize) !void {
    const s = cfg.rc.segments_splits_max;

    try rays.resize(n);
    try segments.pos.resize(n * s * segments_max);
    try segments.cell.resize(n * s * segments_max);
    try segments.sub_sample_level.resize(n * s * segments_max);
    try segments.d.resize(n * s * segments_max);
}

fn freeMemory() void {
    rays.deinit();
    segments.pos.deinit();
    segments.cell.deinit();
    segments.sub_sample_level.deinit();
    segments.d.deinit();
}

fn reallocRaysOnChange() !void {
    if (gfx_core.getWindowWidth() / cfg.sub_sampling_base != rays.items.len) {
        log_ray.debug("Reallocating memory for ray data", .{});

        try resizeDataStructures(gfx_core.getWindowWidth() / cfg.sub_sampling_base);

        log_ray.debug("Window resized, changing number of initial rays -> {}", .{rays.items.len});
    }
}

fn traceMultipleRays(i_0: usize, i_1: usize, angle_0: f32, inc: f32) void {
    const p_x = plr.getPosX();
    const p_y = plr.getPosY();

    var i = i_0;
    var angle = angle_0;

    while (i < i_1) {
        const j = segments_max * i;
        rays.items[i].seg_i0 = j;
        rays.items[i].seg_i1 = j;
        segments.pos.items[j].x0 = p_x;
        segments.pos.items[j].y0 = p_y;
        segments.sub_sample_level.items[j] = 1;

        traceSingleSegment(angle, j, i);

        i += 1;
        angle += inc;
    }
    if (cfg.multithreading) thread_group_rays.finish();
}

inline fn traceSingleSegment(angle: f32, s_i: usize, r_i: usize) void {
    const d_x = @cos(angle); // direction x
    const d_y = @sin(angle); // direction y
    traceSingleSegment0(d_x, d_y, s_i, r_i, .floor, 1.0, segments_max - 1);
}

const Axis = enum { x, y };

const ContactData = struct {
    axis: Axis,
    finish_segment: bool,
    prepare_next_segment: bool,
    reflection_limit: i8,
    cell_type_prev: map.CellType,
};

const TraceData = struct {
    d_x0: f32 = 1, // initial direction, normalised
    d_y0: f32 = 0,
    d_x: f32 = 1,  // direction
    d_y: f32 = 0,
    g_x: f32 = 1, // gradient of segment
    g_y: f32 = 1,
    n_prev: f32 = 1, // material index of previous cell
    o_x: f32 = 0.5, // offset depending on direction to test within cell
    o_y: f32 = 0.5,
    sign_x: f32 = 1, // cell stepping directional sign
    sign_y: f32 = 1,
    s_x: f32 = 1, // current end position of segment
    s_y: f32 = 1,
    r_i: usize = 0, // index of currently traced ray
    s_i: usize = 0, // index of currently traced segment
    m_x: usize = 1, // position in map (cell index)
    m_y: usize = 1,
    axis: Axis = .y,
};

fn traceSingleSegment0(d_x0: f32, d_y0: f32, s_i: usize, r_i: usize, c_prev: map.CellType, n_prev: f32, refl_lim: i8) void {

    var trace_data: TraceData = .{};

    trace_data.s_x = segments.pos.items[s_i].x0;
    trace_data.s_y = segments.pos.items[s_i].y0;
    trace_data.d_x0 = d_x0;
    trace_data.d_y0 = d_y0;
    trace_data.d_x = d_x0;
    trace_data.d_y = d_y0;
    trace_data.g_x = trace_data.d_y / trace_data.d_x; // gradient/derivative of the segment for direction x
    trace_data.g_y = trace_data.d_x / trace_data.d_y; // gradient/derivative of the segment for direction y
    trace_data.n_prev = n_prev;
    trace_data.sign_x = std.math.sign(d_x0);
    trace_data.sign_y = std.math.sign(d_y0);
    trace_data.r_i = r_i;
    trace_data.s_i = s_i;

    if (@abs(trace_data.d_x) > @abs(trace_data.d_y)) trace_data.axis = .x;

    var contact_data: ContactData = .{
        .axis = .x,
        .finish_segment = false,
        .prepare_next_segment = true,
        .reflection_limit = refl_lim,
        .cell_type_prev = c_prev
    };

    var split = false;
    while (!contact_data.finish_segment) {
        trace_data.o_x = 0;
        trace_data.o_y = 0;
        contact_data.axis = .x;

        // if (!split) {
            advanceToNextCell(&trace_data, &contact_data);
        // }

        trace_data.m_y = @intFromFloat(trace_data.s_y + trace_data.o_y);
        trace_data.m_x = @intFromFloat(trace_data.s_x + trace_data.o_x);
        if (trace_data.m_y > map.get().len - 1) trace_data.m_y = map.get().len - 1;
        if (trace_data.m_x > map.get()[0].len - 1) trace_data.m_x = map.get()[0].len - 1;
        const m_v = map.get()[trace_data.m_y][trace_data.m_x];

        // React to cell type
        switch (m_v) {
            .floor => {
                // if (map.get()[@intFromFloat(plr.getPosY())][@intFromFloat(plr.getPosX())] == .wall_thin) {
                // if (contact_data.cell_type_prev == .wall_thin) {
                    // contact_data = resolveContactWallThin(&trace_data, &contact_data);
                // } else {
                    resolveContactFloor(&trace_data, &contact_data);
                // }
            },
            .wall => {
                resolveContactWall(&trace_data, &contact_data);
            },
            .wall_thin => {
                resolveContactWallThin(&trace_data, &contact_data);
            },
            .mirror => {
                resolveContactMirror(&trace_data, &contact_data);
            },
            .glass => {
                if (!split) {
                    resolveContactGlass(&trace_data, &contact_data);
                    split = true;
                } else {
                    // resolveContactMirror(&trace_data, &contact_data);
                    // split = false;
                }
            },
            .pillar => {
                resolveContactPillar(&trace_data, &contact_data);
            },
            // .pillar_glass => {
                // contact_data = resolveContactPillarGlass(&d_x, &d_y, &s_x, &s_y, m_x, m_y, m_v, refl_lim, d_x0, d_y0, s_i, r_i);
            // },
            else => {
                resolveContactFloor(&trace_data, &contact_data);
            }
        }

        proceedPostContact(&trace_data, &contact_data);
    }
}

fn advanceToNextCell(t: *TraceData, cd: *ContactData) void {
    if (t.sign_x == 1) {
        t.d_x = @trunc(t.s_x + 1) - t.s_x;
    } else {
        t.d_x = @ceil(t.s_x - 1) - t.s_x;
    }
    if (t.sign_y == 1) {
        t.d_y = @trunc(t.s_y + 1) - t.s_y;
    } else {
        t.d_y = @ceil(t.s_y - 1) - t.s_y;
    }

    if (t.axis == .x) {
        if (@abs(t.d_x * t.g_x) < @abs(t.d_y)) {
            t.s_x += t.d_x;
            t.s_y += @abs(t.d_x * t.g_x) * t.sign_y;
            if (t.sign_x == -1) t.o_x = -0.5;
            cd.axis = .y;
        } else {
            t.s_x += @abs(t.d_y * t.g_y) * t.sign_x;
            t.s_y += t.d_y;
            if (t.sign_y == -1) t.o_y = -0.5;
            cd.axis = .x;
        }
    } else { // (axis.* == .y)
        if (@abs(t.d_y * t.g_y) < @abs(t.d_x)) {
            t.s_x += @abs(t.d_y * t.g_y) * t.sign_x;
            t.s_y += t.d_y;
            if (t.sign_y == -1) t.o_y = -0.5;
            cd.axis = .x;
        } else {
            t.s_x += t.d_x;
            t.s_y += @abs(t.d_x * t.g_x) * t.sign_y;
            if (t.sign_x == -1) t.o_x = -0.5;
            cd.axis = .y;
        }
    }
}

fn resolveContactFloor(t: *TraceData, c: *ContactData) void {
    if (c.cell_type_prev == .glass) {
        t.n_prev = map.getGlass(t.m_y, t.m_x).n;
        const n = 1.0 / t.n_prev;
        const refl = std.math.asin(@as(f32, n));
        if (c.axis == .x) {
            const alpha = std.math.atan2(@abs(t.d_x0), @abs(t.d_y0));
            // total inner reflection?
            if (alpha > refl) {
                t.d_y = -t.d_y0;
                t.d_x = t.d_x0;
                c.cell_type_prev = .glass;
            } else {
                // const beta = std.math.asin(@sin(alpha) / n);
                // ...
                // d_x.* = @sin(beta);
                // This can be optimised a little:
                const beta_x = @sin(alpha) / n;
                const beta_y = std.math.asin(beta_x);
                t.d_x = beta_x;
                t.d_y = @cos(beta_y);
                if (t.d_x0 < 0) t.d_x = -t.d_x;
                if (t.d_y0 < 0) t.d_y = -t.d_y;
                c.cell_type_prev = .floor;
            }
        } else { // contact_axis == .y
            const alpha = std.math.atan2(@abs(t.d_y0), @abs(t.d_x0));
            // total inner reflection?
            if (alpha > refl) {
                t.d_y = t.d_y0;
                t.d_x = -t.d_x0;
                c.cell_type_prev = .glass;
            } else {
                // const beta = std.math.asin(@sin(alpha) / n);
                // ...
                // d_y.* = @sin(beta);
                // This can be optimised a little:
                const beta_y = @sin(alpha) / n;
                const beta_x = std.math.asin(beta_y);
                t.d_y = beta_y;
                t.d_x = @cos(beta_x);
                if (t.d_x0 < 0) t.d_x = -t.d_x;
                if (t.d_y0 < 0) t.d_y = -t.d_y;
                c.cell_type_prev = .floor;
            }
        }
        c.finish_segment = true;
        c.prepare_next_segment = true;
        c.reflection_limit = @min(c.reflection_limit, map.getReflection(t.m_y, t.m_x).limit) - 1;
    } else {
        t.n_prev = 1.0;
        c.cell_type_prev = .floor;
        c.finish_segment = false;
        c.prepare_next_segment = false;
        c.reflection_limit = @min(c.reflection_limit, map.getReflection(t.m_y, t.m_x).limit);
    }
}

fn resolveContactWall(t: *TraceData, cd: *ContactData) void {
    const hsh = std.hash.Murmur3_32;
    const scatter = 1.0 - 2.0 * @as(f32, @floatFromInt(hsh.hashUint32(@intCast(t.r_i)))) / std.math.maxInt(u32);
    const scatter_f = map.getReflection(t.m_y, t.m_x).diffusion;
    if (cd.axis == .x) {
        t.d_y = -t.d_y0;
        t.d_x = t.d_x0 + scatter * scatter_f;
    } else {
        t.d_x = -t.d_x0;
        t.d_y = t.d_y0 + scatter * scatter_f;
    }
    const r_lim = @min(cd.reflection_limit, map.getReflection(t.m_y, t.m_x).limit);

    cd.finish_segment = true;
    cd.prepare_next_segment = true;
    cd.reflection_limit = r_lim - 1;
    cd.cell_type_prev = .wall;
}

fn resolveContactWallThin(t: *TraceData, cd: *ContactData) void {
    const hsh = std.hash.Murmur3_32;
    const scatter = 1.0 - 2.0 * @as(f32, @floatFromInt(hsh.hashUint32(@intCast(t.r_i)))) / std.math.maxInt(u32);
    const scatter_f = map.getReflection(t.m_y, t.m_x).diffusion;
    const axis = map.getWallThin(t.m_y, t.m_x).axis;
    const from = map.getWallThin(t.m_y, t.m_x).from;
    const to = map.getWallThin(t.m_y, t.m_x).to;
    const r_lim = @min(cd.reflection_limit, map.getReflection(t.m_y, t.m_x).limit);

    // Default: nothing's hit, pass through
    cd.finish_segment = false;
    cd.prepare_next_segment = false;
    cd.reflection_limit = r_lim - 1;
    cd.cell_type_prev = .wall_thin;

    if (axis == .x) {
        if (cd.axis == .y) {
            // c_y: contact on y-axis at cell border
            // s_y is always positive (coordinate on map)
            const c_y = t.s_y - @trunc(t.s_y);
            if (c_y >= from and c_y <= to) {
                t.d_x = -t.d_x0;
                t.d_y = t.d_y0 + scatter * scatter_f;
                cd.finish_segment = true;
                cd.prepare_next_segment = true;
            } else if (c_y < from and t.d_y0 > 0.0) {
                // c_yw: contact y on wall within cell
                const c_yw = (from - c_y) * t.d_x0 / t.d_y0;
                if (@abs(c_yw) >= 0.0 and @abs(c_yw) <= 1.0) {
                    t.s_x += c_yw;
                    t.s_y += from - c_y;
                    t.d_x = t.d_x0 + scatter * scatter_f;
                    t.d_y = -t.d_y0;
                    cd.axis = .x;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            } else if (c_y > to and t.d_y0 < 0.0) {
                // c_yw: contact y on wall within cell
                const c_yw = (c_y - to) * t.d_x0 / t.d_y0;
                if (@abs(c_yw) >= 0.0 and @abs(c_yw) <= 1.0) {
                    t.s_x -= c_yw;
                    t.s_y -= c_y - to;
                    t.d_x = t.d_x0 + scatter * scatter_f;
                    t.d_y = -t.d_y0;
                    cd.axis = .x;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            }
        } else { // if (contact_axis.* == .x) {
            // c_x: contact on x-axis at cell border
            // s_x is always positive (coordinate on map)
            const c_x = t.s_x - @trunc(t.s_x);
            if (t.d_y0 > 0.0) {
                const c_xw = c_x + from * t.d_x0 / t.d_y0;
                if (c_xw >= 0.0 and c_xw <= 1.0) {
                    t.s_x += from * t.d_x0 / t.d_y0;
                    t.s_y += from;
                    t.d_x = t.d_x0 + scatter * scatter_f;
                    t.d_y = -t.d_y0;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            } else if (t.d_y0 < 0.0) {
                const c_xw = c_x - (1.0 - to) * t.d_x0 / t.d_y0;
                if (c_xw >= 0.0 and c_xw <= 1.0) {
                    t.s_x -= (1.0 - to) * t.d_x0 / t.d_y0;
                    t.s_y -= 1.0 - to;
                    t.d_x = t.d_x0 + scatter * scatter_f;
                    t.d_y = -t.d_y0;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            }
        }
    } else { // if (axis == .y) {
        if (cd.axis == .x) {
            // c_x: contact on x-axis at cell border
            // s_x is always positive (coordinate on map)
            const c_x = t.s_x - @trunc(t.s_x);
            if (c_x >= from and c_x <= to) {
                t.d_x = t.d_x0 + scatter * scatter_f;
                t.d_y = -t.d_y0;
                cd.finish_segment = true;
                cd.prepare_next_segment = true;
            } else if (c_x < from and t.d_x0 > 0.0) {
                // c_xw: contact x on wall within cell
                const c_xw = (from - c_x) * t.d_y0 / t.d_x0;
                if (@abs(c_xw) >= 0.0 and @abs(c_xw) <= 1.0) {
                    t.s_x += from - c_x;
                    t.s_y += c_xw;
                    t.d_x = -t.d_x0;
                    t.d_y = t.d_y0 + scatter * scatter_f;
                    cd.axis = .y;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            } else if (c_x > to and t.d_x0 < 0.0) {
                // c_xw: contact x on wall within cell
                const c_xw = (c_x - to) * t.d_y0 / t.d_x0;
                if (@abs(c_xw) >= 0.0 and @abs(c_xw) <= 1.0) {
                    t.s_x -= c_x - to;
                    t.s_y -= c_xw;
                    t.d_x = -t.d_x0;
                    t.d_y = t.d_y0 + scatter * scatter_f;
                    cd.axis = .y;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            }
        } else { // if (contact_axis.* == .y) {
            // c_y: contact on x-axis at cell border
            // s_y is always positive (coordinate on map)
            const c_y = t.s_y - @trunc(t.s_y);
            if (t.d_x0 > 0.0) {
                const c_yw = c_y + from * t.d_y0 / t.d_x0;
                if (c_yw >= 0.0 and c_yw <= 1.0) {
                    t.s_x += from;
                    t.s_y += from * t.d_y0 / t.d_x0;
                    t.d_x = -t.d_x0;
                    t.d_y = t.d_y0 + scatter * scatter_f;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            } else if (t.d_x0 < 0.0) {
                const c_yw = c_y - (1.0 - to) * t.d_y0 / t.d_x0;
                if (c_yw >= 0.0 and c_yw <= 1.0) {
                    t.s_x -= 1.0 - to;
                    t.s_y -= (1.0 - to) * t.d_y0 / t.d_x0;
                    t.d_x = -t.d_x0;
                    t.d_y = t.d_y0 + scatter * scatter_f;
                    cd.finish_segment = true;
                    cd.prepare_next_segment = true;
                }
            }
        }
    }
}

fn resolveContactMirror(t: *TraceData, c: *ContactData) void {
    const hsh = std.hash.Murmur3_32;
    const scatter = 1.0 - 2.0 * @as(f32, @floatFromInt(hsh.hashUint32(@intCast(t.r_i)))) / std.math.maxInt(u32);
    const scatter_f = map.getReflection(t.m_y, t.m_x).diffusion;
    if (c.axis == .x) {
        t.d_y = -t.d_y0;
        t.d_x = t.d_x0 + scatter * scatter_f;
    } else {
        t.d_x = -t.d_x0;
        t.d_y = t.d_y0 + scatter * scatter_f;
    }

    c.finish_segment = true;
    c.prepare_next_segment = true;
    c.reflection_limit = @min(c.reflection_limit, map.getReflection(t.m_y, t.m_x).limit) - 1;
    c.cell_type_prev = .mirror;
}

fn resolveContactGlass(t: *TraceData, c: *ContactData) void {
    const n = map.getGlass(t.m_y, t.m_x).n / t.n_prev;
    t.n_prev = map.getGlass(t.m_y, t.m_x).n;

    const r_lim = @min(c.reflection_limit, map.getReflection(t.m_y, t.m_x).limit);

    if (n != 1.0) {
        if (c.axis == .x) {
            const alpha = std.math.atan2(@abs(t.d_x0), @abs(t.d_y0));
            const r = @sin(alpha) / n;
            if (r > 1.0) {
                t.d_x =  t.d_x0;
                t.d_y = -t.d_y0;
            } else {
                const beta = std.math.asin(r);
                t.d_x = r;
                t.d_y = @cos(beta);
                if (t.d_x0 < 0) t.d_x = -t.d_x;
                if (t.d_y0 < 0) t.d_y = -t.d_y;
            }
        } else { // contact_axis == .y
            const alpha = std.math.atan2(@abs(t.d_y0), @abs(t.d_x0));
            const r = @sin(alpha) / n;
            if (r > 1.0) {
                t.d_x = -t.d_x0;
                t.d_y =  t.d_y0;
            } else {
                const beta = std.math.asin(r);
                t.d_y = r;
                t.d_x = @cos(beta);
                if (t.d_x0 < 0) t.d_x = -t.d_x;
                if (t.d_y0 < 0) t.d_y = -t.d_y;
            }
        }
        c.finish_segment = true;
        c.prepare_next_segment = true;
        c.reflection_limit = r_lim - 1;
        c.cell_type_prev = .glass;
    } else {
        c.finish_segment = false;
        c.prepare_next_segment = false;
        c.reflection_limit = r_lim;
        c.cell_type_prev = .glass;
    }
}

fn resolveContactPillar(t: *TraceData, c: *ContactData) void {
    const r_lim = @min(c.reflection_limit, map.getReflection(t.m_y, t.m_x).limit);
    const pillar = map.getPillar(t.m_y, t.m_x);
    const e_x = @as(f32, @floatFromInt(t.m_x)) + pillar.center_x - t.s_x;
    const e_y = @as(f32, @floatFromInt(t.m_y)) + pillar.center_y - t.s_y;
    const e_norm_sqr = e_x * e_x + e_y * e_y;
    const c_a = e_x * t.d_x0 + t.d_y0 * e_y;
    const r = pillar.radius;
    const w = r * r - (e_norm_sqr - c_a * c_a);

    c.finish_segment = false;
    c.prepare_next_segment = false;
    c.reflection_limit = r_lim;
    c.cell_type_prev = .pillar;

    if (w >= 0) {
        const d_p = c_a - @sqrt(w);
        if (d_p >= 0) {
            segments.d.items[t.s_i] = d_p;
            segments.cell.items[t.s_i].x = t.m_x;
            segments.cell.items[t.s_i].y = t.m_y;
            segments.cell.items[t.s_i].t = .pillar;

            segments.pos.items[t.s_i].x1 = t.s_x + t.d_x0 * d_p;
            segments.pos.items[t.s_i].y1 = t.s_y + t.d_y0 * d_p;

            const r_x = (t.d_x0 * d_p - e_x) / r;
            const r_y = (t.d_y0 * d_p - e_y) / r;
            t.d_x = 2 * (-e_x * r_x - e_y * r_y) * r_x - t.d_x0 * d_p;
            t.d_y = 2 * (-e_x * r_x - e_y * r_y) * r_y - t.d_y0 * d_p;

            const s_x0 = segments.pos.items[t.s_i].x0;
            const s_y0 = segments.pos.items[t.s_i].y0;
            const s_dx = t.s_x - s_x0;
            const s_dy = t.s_y - s_y0;
            // Accumulate distances, if first segment, set
            if (t.s_i > rays.items[t.r_i].seg_i0) {
                segments.d.items[t.s_i] = segments.d.items[t.s_i - 1] + @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            } else {
                segments.d.items[t.s_i] = @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            }

            t.s_x += t.d_x0 * d_p;
            t.s_y += t.d_y0 * d_p;

            c.finish_segment = true;
            c.prepare_next_segment = true;
            c.reflection_limit = r_lim - 1;
            c.cell_type_prev = .pillar;
        }
    }
}

fn resolveContactPillarGlass(d_x: *f32, d_y: *f32, s_x: *f32, s_y: *f32,
                                    m_x: usize, m_y: usize, m_v: map.CellType,
                                    refl_lim: i8, d_x0: f32, d_y0: f32,
                                    s_i: usize, r_i: usize) ContactData {
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
            segments.d.items[s_i] = d_p;
            segments.cell.items[s_i].x = m_x;
            segments.cell.items[s_i].y = m_y;
            segments.cell.items[s_i].t = m_v;

            segments.pos.items[s_i].x1 = s_x.* + d_x0 * d_p;
            segments.pos.items[s_i].y1 = s_y.* + d_y0 * d_p;

            const norm = std.math.atan2(f32, d_y0 * d_p - pillar.center_y,
                                             d_x0 * d_p - pillar.center_x);
            const alpha = std.math.atan2(f32, d_y0, d_x0) - norm;

                          // std.math.atan2(f32, d_y0 * d_p - pillar.center_y,
                          //                     d_x0 * d_p - pillar.center_x);
                        // std.math.atan2(f32, d_y0 * d_p - @intToFloat(f32, m_y) + pillar.center_y,
                        //                     d_x0 * d_p - @intToFloat(f32, m_x) + pillar.center_x);
            // if (alpha >  std.math.pi) alpha -= 2.0 * std.math.pi;
            // if (alpha < -std.math.pi) alpha += 2.0 * std.math.pi;
            const beta = alpha / n;
            d_y.* = @sin(beta + norm);
            d_x.* = @cos(beta + norm);

            // const r_x = (d_x0 * d_p - e_x) / r;
            // const r_y = (d_y0 * d_p - e_y) / r;
            // d_x.* = 2 * (-e_x * r_x - e_y * r_y) * r_x - d_x0 * d_p;
            // d_y.* = 2 * (-e_x * r_x - e_y * r_y) * r_y - d_y0 * d_p;

            const s_x0 = segments.pos.items[s_i].x0;
            const s_y0 = segments.pos.items[s_i].y0;
            const s_dx = s_x.* - s_x0;
            const s_dy = s_y.* - s_y0;
            // Accumulate distances, if first segment, set
            if (s_i > rays.items[r_i].seg_i0) {
                segments.d.items[s_i] = segments.d.items[s_i - 1] + @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            } else {
                segments.d.items[s_i] = @sqrt(s_dx * s_dx + s_dy * s_dy) + d_p;
            }

            s_x.* += d_x0 * d_p;
            s_y.* += d_y0 * d_p;

            return .{ .finish_segment = true, .prepare_next_segment = true, .reflection_limit = r_lim - 1, .cell_type_prev = .pillar_glass };
        }
    }
    return .{ .finish_segment = false, .prepare_next_segment = false, .reflection_limit = r_lim, .cell_type_prev = .pillar };
}

fn proceedPostContact(t: *TraceData, cd: *ContactData) void {
    segments.cell.items[t.s_i].contact_axis = cd.axis;

    // if there is any kind of contact and a the segment ends, save all
    // common data
    const m_v = map.get()[t.m_y][t.m_x];
    if (cd.finish_segment == true and m_v != .pillar and m_v != .pillar_glass) {
        if (cd.cell_type_prev == .glass and m_v == .floor) {
            const s_ip = t.s_i - 1;
            segments.cell.items[t.s_i].x = segments.cell.items[s_ip].x;
            segments.cell.items[t.s_i].y = segments.cell.items[s_ip].y;
            segments.cell.items[t.s_i].t = segments.cell.items[s_ip].t;
        } else {
            segments.cell.items[t.s_i].x = t.m_x;
            segments.cell.items[t.s_i].y = t.m_y;
            segments.cell.items[t.s_i].t = m_v;
        }
        var pos = &segments.pos.items[t.s_i];
        pos.x1 = t.s_x;
        pos.y1 = t.s_y;
        const s_x0 = pos.x0;
        const s_y0 = pos.y0;
        const s_dx = t.s_x - s_x0;
        const s_dy = t.s_y - s_y0;

        // Accumulate distances, if first segment, set
        if (t.s_i > rays.items[t.r_i].seg_i0) {
            segments.d.items[t.s_i] = segments.d.items[t.s_i - 1] + @sqrt(s_dx * s_dx + s_dy * s_dy);
        } else {
            segments.d.items[t.s_i] = @sqrt(s_dx * s_dx + s_dy * s_dy);
        }
    }
    // Prepare next segment
    // Only prepare next segment if not already the last segment of the
    // last ray!
    if (cd.prepare_next_segment and t.s_i + 1 < rays.items.len * segments_max) {
        // Just be sure to stay below the maximum segment number per ray
        // if ((rays.seg_i1[r_i] - rays.seg_i0[r_i]) < contact_data.reflection_limit) {
        const refl = cd.reflection_limit + 1;
        if (refl > 0) {
            const subs = map.getReflection(t.m_y, t.m_x).sub_sampling;
            if (t.r_i % subs == 0) {
                segments.pos.items[t.s_i + 1].x0 = t.s_x;
                segments.pos.items[t.s_i + 1].y0 = t.s_y;
                segments.sub_sample_level.items[t.s_i + 1] = segments.sub_sample_level.items[t.s_i] * subs;
                rays.items[t.r_i].seg_i1 += 1;
                traceSingleSegment0(t.d_x, t.d_y, t.s_i + 1, t.r_i, cd.cell_type_prev, t.n_prev, cd.reflection_limit);
            }
        }
    }
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "raycaster: init/deinit" {
    try gfx_core.init();
    try gfx_base.init();
    try gfx_rw.init();
    try map.init();
    try init();
    // try processRays(true);
    defer gfx_core.deinit();
    defer gfx_base.deinit();
    defer gfx_rw.deinit();
    defer deinit();
    defer map.deinit();
}
