const std = @import("std");
const cfg = @import("config.zig");
const gfx = @import("graphics.zig");
const map = @import("map.zig");
const stats = @import("stats.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    log_ray.debug("Allocating memory for ray data", .{});
    perf_mem = try stats.Performance.init("Graphics memory allocation");
    perf_mem.startMeasurement();

    try allocMemory(640);

    perf_mem.stopMeasurement();

    cpus = try std.Thread.getCpuCount();
    if (cpus > cfg.rc.threads_max) cpus = cfg.rc.threads_max;
    log_ray.info("Utilising {} logical cpu cores for multithreading", .{cpus});
}

pub fn deinit() void {
    freeMemory();

    const leaked = gpa.deinit();
    if (leaked) log_ray.err("Memory leaked in GeneralPurposeAllocator", .{});

    perf_mem.printStats();
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn createMap() void {
    const m = map.get();
    const map_cells_y = @intToFloat(f32, map.get().len);
    const win_h = @intToFloat(f32, gfx.getWindowHeight());
    const f = win_h * cfg.rc.map_display_height / map_cells_y; // scale factor cell -> px
    const o = win_h-f*map_cells_y; // y-offset for map drawing in px

    gfx.startBatchQuads();
    for (m) |y,j| {
        for (y) |cell,i| {
            const c = map.getColor(j, i);
            switch (cell) {
                .floor => {
                    gfx.setColor4(0.2+0.1*c.r, 0.2+0.1*c.g, 0.2+0.1*c.b, cfg.rc.map_display_opacity);
                },
                .wall, .wall_thin, .mirror, .glass, .pillar => {
                    gfx.setColor4(0.3+0.3*c.r, 0.3+0.3*c.g, 0.3+0.3*c.b, cfg.rc.map_display_opacity);
                },
            }

            gfx.addQuad(@intToFloat(f32, i)*f, o+@intToFloat(f32, j)*f,
                        @intToFloat(f32, (i+1))*f, o+@intToFloat(f32, (j+1))*f);
        }
    }
    gfx.endBatch();

    var i: usize = 0;

    gfx.setColor4(0.0, 0.0, 1.0, 0.1);
    gfx.startBatchLine();
    while (i < rays.seg_i0.len) : (i += 1) {
        if (i % cfg.rc.map_display_every_nth_line == 0) {
            var j = @intCast(i32, rays.seg_i1[i]);
            const j0 = rays.seg_i0[i];

            if (j-@intCast(i32, j0) > cfg.rc.map_display_reflections_max) {
                j = @intCast(i32, j0) + cfg.rc.map_display_reflections_max;
            }
            const color_step = 1.0 / @intToFloat(f32, cfg.rc.map_display_reflections_max+1);

            while (j >= j0) : (j -= 1) {
                const color_grade = color_step*@intToFloat(f32, @intCast(usize, j)-j0);
                if (j == j0) {
                    gfx.setColor4(0.0, 0.0, 1.0, 0.5);
                } else {
                    gfx.setColor4(0.0, 1-color_grade, 1.0, 0.2*(1-color_grade));
                }
                const k = @intCast(usize, j);
                gfx.addLine(segments.x0[k]*f, o+segments.y0[k]*f,
                            segments.x1[k]*f, o+segments.y1[k]*f);
            }
        }
    }
    gfx.endBatch();

    const x = plr.getPosX();
    const y = plr.getPosY();
    const w = 0.1;
    const h = 0.5;
    const d = plr.getDir();
    gfx.setColor4(0.0, 0.7, 0.0, 1.0);
    gfx.drawTriangle((x-w*@sin(d))*f, o+(y+w*@cos(d))*f,
                     (x+h*@cos(d))*f, o+(y+h*@sin(d))*f,
                     (x+w*@sin(d))*f, o+(y-w*@cos(d))*f);
}

pub fn createScene() void {

    const win_h = @intToFloat(f32, gfx.getWindowHeight());

    var i: usize = 0;

    while (i < rays.seg_i0.len) : (i += 1) {

        const j0 = rays.seg_i0[i];
        const j1 = rays.seg_i1[i];
        var j = j1;

        // Angle between current ray and player direction
        const ang_0 = (@intToFloat(f32, i) / @intToFloat(f32, rays.seg_i0.len)-0.5) * plr.getFOV();

        const tilt = -win_h * plr.getTilt();

        const x = @intToFloat(f32, i);
        gfx.addVerticalLineC2C(x, 0, win_h*0.5+tilt,
                               0.3, 0, 1, 11);
        gfx.addVerticalLineC2C(x, win_h*0.5+tilt, win_h,
                               0, 0.1, 1, 11);
        while (j >= j0) : (j -= 1){

            const depth_layer = @intCast(u8, j-j0+1);
            // Use an optical pleasing combination of the natural lense effect due
            // to a "point" camera and the "straight line correction". This results
            // in little dynamic changes when rotating the camera (instead of just)
            // moving the still scene on the screen) as well as the non-linearity
            // that differentiates it from polygons
            const k = @intCast(usize, j);
            var d = segments.d[k];
            d *= (0.5 + 0.5 * @cos(ang_0));

            // Restrict minimum distance, i.e. maximum height drawn
            if (d < 0.5) d = 0.5;
            var d_norm = 2 / d; // At 2m distance, the walls are screen filling (w.r.t. height)
            const h_half = win_h * d_norm * 0.5;

            // For colours, do not increase d_norm too much for distances < 2m,
            // since colors become white, otherwise
            if (d_norm > 1) d_norm = 1;

            const shift_and_tilt = win_h * plr.getPosZ() / (d+1e-3) + tilt;

            const m_x = segments.cell_x[k];
            const m_y = segments.cell_y[k];

            var u_of_uv: f32 = 0;
            if (segments.cell_type[k] != .pillar) {
                if (segments.x1[k] - @trunc(segments.x1[k]) > segments.y1[k] - @trunc(segments.y1[k])) {
                    u_of_uv = segments.x1[k] - @trunc(segments.x1[k]);
                    if (segments.y0[k] < segments.y1[k]) {
                        u_of_uv = 1 - u_of_uv;
                    }
                } else {
                    u_of_uv = segments.y1[k] - @trunc(segments.y1[k]);
                    if (segments.x0[k] > segments.x1[k]) {
                        u_of_uv = 1 - u_of_uv;
                    }
                }
            } else {
                const p_x = segments.x1[k] - @intToFloat(f32, m_x);
                const p_y = segments.y1[k] - @intToFloat(f32, m_y);
                const dir_x = p_x - map.getPillar(m_y, m_x).center_x;
                const dir_y = p_y - map.getPillar(m_y, m_x).center_y;
                var angle = std.math.atan2(f32, dir_y, dir_x);
                if (angle < 0) angle += 2.0*std.math.pi;
                if (angle > 2.0*std.math.pi) angle -= 2.0*std.math.pi;
                const circ = 2.0 * std.math.pi;
                u_of_uv = 1.0 - angle / circ;
            }

            const col = map.getColor(m_y, m_x);
            const canvas = map.getCanvas(m_y, m_x);
            const tex_id = map.getTextureID(m_y, m_x).id;

            const h_half_top = h_half*@mulAdd(f32, -2, canvas.top, 1); // h_half*(1-2*canvas_top);
            const h_half_bottom = h_half*@mulAdd(f32, -2, canvas.bottom, 1); // h_half*(1-2*canvas_bottom);
            if (tex_id != 0) {
                gfx.addVerticalTexturedLine(x, win_h*0.5 - h_half_top + shift_and_tilt,
                                                win_h*0.5 + h_half_bottom + shift_and_tilt,
                                            u_of_uv, 0, 1,
                                            d_norm*col.r, d_norm*col.g, d_norm*col.b, col.a,
                                            depth_layer, tex_id);
            } else {
                gfx.addVerticalLine(x, win_h*0.5 - h_half_top + shift_and_tilt,
                                        win_h*0.5 + h_half_bottom + shift_and_tilt,
                                    d_norm*col.r, d_norm*col.g, d_norm*col.b, col.a,
                                    depth_layer);
            }
            if (canvas.bottom+canvas.top > 0.0) {
                if (canvas.tex_id != 0) {
                    gfx.addVerticalTexturedLine(x, win_h*0.5-h_half + shift_and_tilt,
                                                win_h*0.5-h_half_top + shift_and_tilt,
                                                u_of_uv, 0, canvas.top,
                                                d_norm*canvas.r, d_norm*canvas.g, d_norm*canvas.b, canvas.a,
                                                depth_layer, canvas.tex_id);
                    gfx.addVerticalTexturedLine(x, win_h*0.5+h_half + shift_and_tilt,
                                                win_h*0.5+h_half_bottom + shift_and_tilt,
                                                u_of_uv, 1, 1-canvas.bottom,
                                                d_norm*canvas.r, d_norm*canvas.g, d_norm*canvas.b, canvas.a,
                                                depth_layer, canvas.tex_id);
                } else {
                    gfx.addVerticalLine(x, win_h*0.5-h_half + shift_and_tilt,
                                            win_h*0.5-h_half_top + shift_and_tilt,
                                        d_norm*canvas.r, d_norm*canvas.g, d_norm*canvas.b, canvas.a,
                                        depth_layer);
                    gfx.addVerticalLine(x, win_h*0.5+h_half + shift_and_tilt,
                                            win_h*0.5+h_half_bottom + shift_and_tilt,
                                        d_norm*canvas.r, d_norm*canvas.g, d_norm*canvas.b, canvas.a,
                                        depth_layer);
                }
            }
            if (j == j0) {
            //     gfx.addVerticalLineAO(x, win_h*0.5-h_half+shift_and_tilt, win_h*0.5+h_half+shift_and_tilt,
            //                           0, 0.5*d_norm, 0.4, depth_layer);
                break;
            }
        }
    }
}

pub fn processRays(comptime multithreading: bool) !void {
    try reallocRaysOnChange();

    var angle: f32 = @mulAdd(f32, -0.5, plr.getFOV(), plr.getDir());
    const inc_angle: f32 = plr.getFOV() / @intToFloat(f32, rays.seg_i0.len);

    const split = rays.seg_i0.len / cpus;

    if (multithreading) {
        var cpu: u8 = 0;
        while (cpu < cpus) : (cpu += 1) {
            var last = (cpu+1)*split;
            if (cpu == cpus-1) last = rays.seg_i0.len;
            threads[cpu] = try std.Thread.spawn(.{}, traceMultipleRays,
                                                .{cpu*split, last,
                                                  @mulAdd(f32, inc_angle, @intToFloat(f32, cpu*split), angle),
                                                  inc_angle});
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

var gpa = if (cfg.debug_allocator)  std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){} else
                                    std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

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
    d:  []f32,
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
    .d  = undefined,
    .cell_type = undefined,
    .cell_x = undefined,
    .cell_y = undefined,
};

var perf_mem: stats.Performance = undefined;

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
    allocator.free(segments.cell_type);
    allocator.free(segments.cell_x);
    allocator.free(segments.cell_y);
}

fn reallocRaysOnChange() !void {
    if (gfx.getWindowWidth() != rays.seg_i0.len) {
        perf_mem.startMeasurement();
        log_ray.debug("Reallocating memory for ray data", .{});

        freeMemory();
        try allocMemory(gfx.getWindowWidth());

        perf_mem.stopMeasurement();
        log_ray.debug("Window resized, changing number of initial rays -> {}", .{rays.seg_i0.len});
    }
}

fn traceMultipleRays(i_0: usize, i_1: usize, angle_0: f32, inc: f32) void {
    const p_x = plr.getPosX();
    const p_y = plr.getPosY();

    var i = i_0;
    var angle = angle_0;

    while (i < i_1) {
        const j = segments_max*i;
        rays.seg_i0[i] = j;
        rays.seg_i1[i] = j;
        segments.x0[j] = p_x;
        segments.y0[j] = p_y;

        traceSingleSegment(angle, j, i);

        i += 1;
        angle += inc;
    }
}

inline fn traceSingleSegment(angle: f32, s_i: usize, r_i: usize) void {
    var d_x = @cos(angle);      // direction x
    var d_y = @sin(angle);      // direction y
    traceSingleSegment0(d_x, d_y, s_i, r_i, .floor, 1.0, segments_max-1);
}

const Axis = enum { x, y };

const ContactStatus = struct {
    finish_segment: bool,
    prepare_next_segment: bool,
    reflection_limit: i8,
    cell_type_prev: map.CellType,
};

fn traceSingleSegment0(d_x0: f32, d_y0: f32,
                       s_i: usize, r_i: usize,
                       c_prev: map.CellType, n_prev: f32, refl_lim: i8) void {

    var s_x = segments.x0[s_i]; // segment pos x
    var s_y = segments.y0[s_i]; // segment pos y
    var d_x = d_x0;             // direction x
    var d_y = d_y0;             // direction y
    const g_x = d_y/d_x;        // gradient/derivative of the segment for direction x
    const g_y = d_x/d_y;        // gradient/derivative of the segment for direction y

    var sign_x: f32 = 1;
    var sign_y: f32 = 1;

    var a: Axis = .y;           // primary axis for stepping
    if (@fabs(d_x) > @fabs(d_y)) a = .x;
    if (d_x < 0) sign_x = -1;
    if (d_y < 0) sign_y = -1;

    var material_index_prev = n_prev;

    var contact_status: ContactStatus = .{.finish_segment = false,
                                          .prepare_next_segment = true,
                                          .reflection_limit = 0,
                                          .cell_type_prev = c_prev};

    while (!contact_status.finish_segment) {

        var o_x: f32 = 0;
        var o_y: f32 = 0;
        var contact_axis: Axis = .x;

        advanceToNextCell(&d_x, &d_y, &s_x, &s_y,
                          &o_x, &o_y, &sign_x, &sign_y,
                          &a, &contact_axis,
                          g_x, g_y);

        var m_y = @floatToInt(usize, s_y+o_y);
        var m_x = @floatToInt(usize, s_x+o_x);
        if (m_y > map.get().len-1) m_y = map.get().len-1;
        if (m_x > map.get()[0].len-1) m_x = map.get()[0].len-1;
        const m_v = map.get()[m_y][m_x];

        // React to cell type
        switch (m_v) {
            .floor => {
                contact_status = resolveContactFloor(&d_x, &d_y, &contact_status.cell_type_prev,
                                                     m_x, m_y,
                                                     contact_axis, refl_lim, d_x0, d_y0);
            },
            .wall => {
                contact_status = resolveContactWall(&d_x, &d_y, m_x, m_y, r_i, contact_axis, refl_lim, d_x0, d_y0);
            },
            .wall_thin => {
                // contact_status = resolveContactWallThin(&d_x, &d_y, &s_x, &s_y, m_x, m_y,
                //                                         r_i, contact_axis, refl_lim, d_x0, d_y0);
            },
            .mirror => {
                contact_status = resolveContactMirror(&d_x, &d_y, m_x, m_y, r_i, contact_axis, refl_lim, d_x0, d_y0);
            },
            .glass => {
                contact_status = resolveContactGlass(&d_x, &d_y, &material_index_prev,
                                                     m_x, m_y,
                                                     contact_status.cell_type_prev,
                                                     contact_axis, refl_lim, d_x0, d_y0);
            },
            .pillar => {
                contact_status = resolveContactPillar(&d_x, &d_y, &s_x, &s_y,
                                                      m_x, m_y, m_v, refl_lim,
                                                      d_x0, d_y0,
                                                      s_i, r_i);
            }
        }

        proceedPostContact(contact_status, m_x, m_y, m_v, c_prev, material_index_prev,
                           s_i, r_i, s_x, s_y, d_x, d_y);
    }
}

inline fn advanceToNextCell(d_x: *f32, d_y: *f32,
                            s_x: *f32, s_y: *f32,
                            o_x: *f32, o_y: *f32,
                            sign_x: *f32, sign_y: *f32,
                            axis: *Axis,
                            contact_axis: *Axis,
                            g_x: f32, g_y: f32) void {
    if (sign_x.* == 1) {
        d_x.* = @trunc(s_x.*+1) - s_x.*;
    } else {
        d_x.* = @ceil(s_x.*-1) - s_x.*;
    }
    if (sign_y.* == 1) {
        d_y.* = @trunc(s_y.*+1) - s_y.*;
    } else {
        d_y.* = @ceil(s_y.*-1) - s_y.*;
    }

    if (axis.* == .x) {
        if (@fabs(d_x.* * g_x) < @fabs(d_y.*)) {
            s_x.* += d_x.*;
            s_y.* += @fabs(d_x.* * g_x) * sign_y.*;
            if (sign_x.* == -1) o_x.* = -0.5;
            contact_axis.* = .y;
        } else {
            s_x.* += @fabs(d_y.* * g_y) * sign_x.*;
            s_y.* += d_y.*;
            if (sign_y.* == -1) o_y.* = -0.5;
            contact_axis.* = .x;
        }
    } else { // (axis.* == .y)
        if (@fabs(d_y.* * g_y) < @fabs(d_x.*)) {
            s_x.* += @fabs(d_y.* * g_y) * sign_x.*;
            s_y.* += d_y.*;
            if (sign_y.* == -1) o_y.* = -0.5;
            contact_axis.* = .x;
        } else {
            s_x.* += d_x.*;
            s_y.* += @fabs(d_x.* * g_x) * sign_y.*;
            if (sign_x.* == -1) o_x.* = -0.5;
            contact_axis.* = .y;
        }
    }
}

inline fn resolveContactFloor(d_x: *f32, d_y: *f32,
                              cell_type_prev: *map.CellType,
                              m_x: usize, m_y: usize,
                              contact_axis: Axis,
                              refl_lim: i8,
                              d_x0: f32, d_y0: f32) ContactStatus {
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);
    if (cell_type_prev.* == .glass) {
        const n = 1.0 / map.getGlass(m_y, m_x).n;
        const refl = std.math.asin(@as(f32,n));
        if (contact_axis == .x) {
            const alpha = std.math.atan2(f32, @fabs(d_x0), @fabs(d_y0));
            // total inner reflection?
            if (alpha > refl) {
                d_y.* = -d_y0;
                d_x.* = d_x0;
                cell_type_prev.* = .glass;
            } else {
                const beta = std.math.asin(std.math.sin(alpha / n));
                d_x.* = @sin(beta);
                d_y.* = @cos(beta);
                if (d_x0 < 0) d_x.* = -d_x.*;
                if (d_y0 < 0) d_y.* = -d_y.*;
                cell_type_prev.* = .floor;
            }
        } else { // contact_axis == .y
            const alpha = std.math.atan2(f32, @fabs(d_y0), @fabs(d_x0));
            // total inner reflection?
            if (alpha > refl) {
                d_y.* = d_y0;
                d_x.* = -d_x0;
                cell_type_prev.* = .glass;
            } else {
                const beta = std.math.asin(std.math.sin(alpha / n));
                d_y.* = @sin(beta);
                d_x.* = @cos(beta);
                if (d_x0 < 0) d_x.* = -d_x.*;
                if (d_y0 < 0) d_y.* = -d_y.*;
                cell_type_prev.* = .floor;
            }
        }
        return .{.finish_segment = true,
                 .prepare_next_segment = true,
                 .reflection_limit = r_lim-1,
                 .cell_type_prev = cell_type_prev.*};
    } else {
        cell_type_prev.* = .floor;
        return .{.finish_segment = false,
                 .prepare_next_segment = false,
                 .reflection_limit = r_lim,
                 .cell_type_prev = cell_type_prev.*};
    }

}

inline fn resolveContactWall(d_x: *f32, d_y: *f32,
                             m_x: usize, m_y: usize,
                             r_i: usize, contact_axis: Axis,
                             refl_lim: i8,
                             d_x0: f32, d_y0: f32) ContactStatus {
    const hsh = std.hash.Murmur3_32;
    var scatter = 1.0 - 2.0 * @intToFloat(f32, hsh.hashUint32(@intCast(u32, r_i)))/std.math.maxInt(u32);
    const scatter_f = map.getReflection(m_y, m_x).diffusion;
    if (contact_axis == .x) {
        d_y.* = -d_y0;
        d_x.* = d_x0+scatter*scatter_f;
    } else {
        d_x.* = -d_x0;
        d_y.* = d_y0+scatter*scatter_f;
    }
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);

    return .{.finish_segment = true,
             .prepare_next_segment = true,
             .reflection_limit = r_lim-1,
             .cell_type_prev = .wall};
}

inline fn resolveContactWallThin(d_x: *f32, d_y: *f32,
                                 s_x: *f32, s_y: *f32,
                                 m_x: usize, m_y: usize,
                                 r_i: usize, contact_axis: Axis,
                                 refl_lim: u8,
                                 d_x0: f32, d_y0: f32) ContactStatus {
    const hsh = std.hash.Murmur3_32;
    var scatter = 1.0 - 2.0 * @intToFloat(f32, hsh.hashUint32(@intCast(u32, r_i)))/std.math.maxInt(u32);
    const scatter_f = map.getReflection(m_y, m_x).diffusion;
    const from = map.getWallThin(m_y, m_x).from;
    const to = map.getWallThin(m_y, m_x).to;
    if (contact_axis == .x) {
        if (d_y.* > 0) {
            if (from * d_x.*/d_y.* + d_x.* > 0 and
                from * d_x.*/d_y.* + d_x.* < 1) {
                s_x.* += from * d_x.*/d_y.*;
                s_y.* += from;
                // d_y.* = -d_y0;
                // d_x.* = d_x0+scatter*scatter_f;
                return .{.finish_segment = true,
                         .prepare_next_segment = false,
                         .reflection_limit = 0,//@min(refl_lim, 2),
                         .cell_type_prev = .wall_thin};
            } else {
                return .{.finish_segment = false,
                         .prepare_next_segment = false,
                         .reflection_limit = @min(refl_lim, 2),
                         .cell_type_prev = .wall_thin};
            }
        } else {
            if (to * d_x.*/d_y.* + d_x.* > 0 and
                to * d_x.*/d_y.* + d_x.* < 1) {
                s_x.* += to * d_x.*/d_y.*;
                s_y.* += to;
                d_y.* = -d_y0;
                d_x.* = d_x0+scatter*scatter_f;
            } else {
                return .{.finish_segment = false,
                         .prepare_next_segment = false,
                         .reflection_limit = @min(refl_lim, 2),
                         .cell_type_prev = .wall_thin};
            }
        }
        // if (d_y.* < 0 and
        //     map.getWallThin(m_y, m_x).to * d_x.*/d_y.* + d_x.* > 0 and
        //     map.getWallThin(m_y, m_x).to * d_x.*/d_y.* + d_x.* < 1
        //     ) {
        //     s_x.* += map.getWallThin(m_y, m_x).to * d_x.*/d_y.*;
        //     s_y.* += map.getWallThin(m_y, m_x).to;
        // }
    } else {
        if (d_y.* >= from and d_y.* <= to) {
            d_x.* = -d_x0;
            d_y.* = d_y0+scatter*scatter_f;
        } else {
            if (d_y.* < from and (d_y.* - from) * d_x.*/d_y.* < 1.0) {
                s_x.* += (d_y.* - from) * d_x.*/d_y.*;
                s_y.* += d_y.* - from;
                // d_x.* = -d_x0;
                // d_y.* = d_y0+scatter*scatter_f;
                return .{.finish_segment = true,
                        .prepare_next_segment = false,
                        .reflection_limit = 0,
                        .cell_type_prev = .wall_thin};
            } else {
                return .{.finish_segment = false,
                        .prepare_next_segment = false,
                        .reflection_limit = @min(refl_lim, 2),
                        .cell_type_prev = .wall_thin};
            }
        }
    }

    return .{.finish_segment = true,
             .prepare_next_segment = true,
             .reflection_limit = @min(refl_lim, 2),
             .cell_type_prev = .wall_thin};
}

inline fn resolveContactMirror(d_x: *f32, d_y: *f32,
                               m_x: usize, m_y: usize,
                               r_i: usize, contact_axis: Axis,
                               refl_lim: i8,
                               d_x0: f32, d_y0: f32) ContactStatus {
    const hsh = std.hash.Murmur3_32;
    var scatter = 1.0 - 2.0 * @intToFloat(f32, hsh.hashUint32(@intCast(u32, r_i)))/std.math.maxInt(u32);
    const scatter_f = map.getReflection(m_y, m_x).diffusion;
    if (contact_axis == .x) {
        d_y.* = -d_y0;
        d_x.* = d_x0+scatter*scatter_f;
    } else {
        d_x.* = -d_x0;
        d_y.* = d_y0+scatter*scatter_f;
    }

    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);

    return .{.finish_segment = true,
             .prepare_next_segment = true,
             .reflection_limit = r_lim-1,
             .cell_type_prev = .mirror};
}

inline fn resolveContactGlass(d_x: *f32, d_y: *f32,
                              n_prev: *f32,
                              m_x: usize, m_y: usize,
                              cell_type_prev: map.CellType,
                              contact_axis: Axis,
                              refl_lim: i8,
                              d_x0: f32, d_y0: f32) ContactStatus {
    const n = map.getGlass(m_y, m_x).n / n_prev.*;
    _ = cell_type_prev;
    n_prev.* = map.getGlass(m_y, m_x).n;

    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);

    if (n != 1.0) {
        if (contact_axis == .x) {
            const alpha = std.math.atan2(f32, @fabs(d_x0), @fabs(d_y0));
            const beta = std.math.asin(std.math.sin(alpha / n));
            d_x.* = @sin(beta);
            d_y.* = @cos(beta);
            if (d_x0 < 0) d_x.* = -d_x.*;
            if (d_y0 < 0) d_y.* = -d_y.*;
        } else { // !is_contact_on_x_axis
            const alpha = std.math.atan2(f32, @fabs(d_y0), @fabs(d_x0));
            const beta = std.math.asin(std.math.sin(alpha / n));
            d_y.* = @sin(beta);
            d_x.* = @cos(beta);
            if (d_x0 < 0) d_x.* = -d_x.*;
            if (d_y0 < 0) d_y.* = -d_y.*;
        }
        return .{.finish_segment = true,
                 .prepare_next_segment = true,
                 .reflection_limit = r_lim-1,
                 .cell_type_prev = .glass};
    } else {
        return .{.finish_segment = false,
                 .prepare_next_segment = false,
                 .reflection_limit = r_lim-1,
                 .cell_type_prev = .glass};
    }
}

inline fn resolveContactPillar(d_x: *f32, d_y: *f32,
                               s_x: *f32, s_y: *f32,
                               m_x: usize, m_y: usize, m_v: map.CellType,
                               refl_lim: i8,
                               d_x0: f32, d_y0: f32,
                               s_i: usize, r_i: usize) ContactStatus {
    const r_lim = @min(refl_lim, map.getReflection(m_y, m_x).limit);
    const pillar = map.getPillar(m_y, m_x);
    const e_x = @intToFloat(f32, m_x) + pillar.center_x - s_x.*;
    const e_y = @intToFloat(f32, m_y) + pillar.center_y - s_y.*;
    const e_norm_sqr = e_x*e_x+e_y*e_y;
    const c_a = e_x * d_x0 + d_y0 * e_y;
    const r = pillar.radius;
    const w = r*r - (e_norm_sqr - c_a*c_a);
    if (w >= 0) {
        const d_p = c_a - @sqrt(w);
        if (d_p >= 0) {
            segments.d[s_i] = d_p;
            segments.cell_x[s_i] = m_x;
            segments.cell_y[s_i] = m_y;
            segments.cell_type[s_i] = m_v;

            segments.x1[s_i] = s_x.* + d_x0 * d_p;
            segments.y1[s_i] = s_y.* + d_y0 * d_p;

            const r_x = (d_x0*d_p - e_x) / r;
            const r_y = (d_y0*d_p - e_y) / r;
            d_x.* = 2*(-e_x*r_x - e_y*r_y) * r_x - d_x0*d_p;
            d_y.* = 2*(-e_x*r_x - e_y*r_y) * r_y - d_y0*d_p;

            const s_x0 = segments.x0[s_i];
            const s_y0 = segments.y0[s_i];
            const s_dx = s_x.* - s_x0;
            const s_dy = s_y.* - s_y0;
            // Accumulate distances, if first segment, set
            if (s_i > rays.seg_i0[r_i]) {
                segments.d[s_i] = segments.d[s_i-1] + @sqrt(s_dx*s_dx + s_dy*s_dy) + d_p;
            } else {
                segments.d[s_i] = @sqrt(s_dx*s_dx + s_dy*s_dy) + d_p;
            }

            s_x.* += d_x0*d_p;
            s_y.* += d_y0*d_p;

            return .{.finish_segment = true,
                     .prepare_next_segment = true,
                     .reflection_limit = r_lim-1,
                     .cell_type_prev = .pillar};
        }
    }
    return .{.finish_segment = false,
             .prepare_next_segment = false,
             .reflection_limit = r_lim,
             .cell_type_prev = .pillar};
}

inline fn proceedPostContact(contact_status: ContactStatus,
                             m_x: usize, m_y: usize,
                             m_v: map.CellType, c_prev: map.CellType, n_prev: f32,
                             s_i: usize, r_i: usize,
                             s_x: f32, s_y: f32, d_x: f32, d_y: f32) void {
    // if there is any kind of contact and a the segment ends, save all
    // common data
    if (contact_status.finish_segment == true and m_v != .pillar) {

        if (c_prev == .glass and m_v == .floor) {
            segments.cell_x[s_i] = segments.cell_x[s_i-1];
            segments.cell_y[s_i] = segments.cell_y[s_i-1];
            segments.cell_type[s_i] = segments.cell_type[s_i-1];
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
            segments.d[s_i] = segments.d[s_i-1] + @sqrt(s_dx*s_dx + s_dy*s_dy);
        } else {
            segments.d[s_i] = @sqrt(s_dx*s_dx + s_dy*s_dy);
        }
    }
    // Prepare next segment
    // Only prepare next segment if not already the last segment of the
    // last ray!
    if (contact_status.prepare_next_segment and s_i+1 < rays.seg_i0.len * segments_max) {
        // Just be sure to stay below the maximum segment number per ray
        // if ((rays.seg_i1[r_i] - rays.seg_i0[r_i]) < contact_status.reflection_limit) {
        if (contact_status.reflection_limit+1 > 0) {
            if (r_i % 1 == 0) {
            segments.x0[s_i+1] = s_x;
            segments.y0[s_i+1] = s_y;
            rays.seg_i1[r_i] += 1;
                traceSingleSegment0(d_x, d_y, s_i+1, r_i, contact_status.cell_type_prev, n_prev, contact_status.reflection_limit);
        }}
    }
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "raycaster" {
    try allocMemory(1000);
    freeMemory();
    try allocMemory(10000);
    freeMemory();
    try init();
    defer deinit();
    try map.init();
    defer map.deinit();
    try processRays(false);
    try processRays(true);
}
