const std = @import("std");
const gfx = @import("graphics.zig");
const map = @import("map.zig");
const stats = @import("perf_stats.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    log_ray.debug("Allocating memory for ray data", .{});
    perf_gfx_alloc = try stats.Performance.init("Graphics memory allocation");
    perf_gfx_alloc.startMeasurement();

    try allocMemory(640);

    perf_gfx_alloc.stopMeasurement();
}

pub fn deinit() void {
    freeMemory();

    const leaked = gpa.deinit();
    if (leaked) log_ray.err("Memory leaked in GeneralPurposeAllocator", .{});

    perf_gfx_alloc.printStats();
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn processRays(comptime multithreading: bool) !void {
    try reallocRaysOnChange();

    var angle: f32 = @mulAdd(f32, -0.5, plr.getFOV(), plr.getDir());
    const inc_angle: f32 = plr.getFOV() / @intToFloat(f32, rays.seg_i0.len);

    const split = rays.seg_i0.len / 4;

    if (multithreading) {
        var thread_0 = try std.Thread.spawn(.{}, traceMultipleRays, .{0, split, angle, inc_angle});
        var thread_1 = try std.Thread.spawn(.{}, traceMultipleRays,
                                            .{split, 2*split, @mulAdd(f32, inc_angle, @intToFloat(f32, split), angle), inc_angle});
        var thread_2 = try std.Thread.spawn(.{}, traceMultipleRays,
                                            .{2*split, 3*split, @mulAdd(f32, inc_angle, @intToFloat(f32, 2*split), angle), inc_angle});
        var thread_3 = try std.Thread.spawn(.{}, traceMultipleRays,
                                            .{3*split, rays.seg_i0.len, @mulAdd(f32, inc_angle, @intToFloat(f32, 3*split), angle), inc_angle});
        thread_0.join();
        thread_1.join();
        thread_2.join();
        thread_3.join();
    } else {
        traceMultipleRays(0, rays.seg_i0.len, angle, inc_angle);
    }
}

pub fn showMap() void {
    const m = map.get();
    const map_cells_y = @intToFloat(f32, map.get().len);
    const map_vis_y = 0.3;
    const win_h = @intToFloat(f32, gfx.getWindowHeight());
    const f = win_h * map_vis_y / map_cells_y; // scale factor cell -> px
    const o = win_h-f*map_cells_y; // y-offset for map drawing in px

    gfx.startBatchQuads();
    for (m) |y,j| {
        for (y) |x,i| {
            if (x == 0) {
                gfx.setColor4(0.2, 0.2, 0.2, 0.3);
            } else {
                gfx.setColor4(1.0, 1.0, 1.0, 0.3);
            }
            gfx.addQuad(@intToFloat(f32, i)*f, o+@intToFloat(f32, j)*f,
                        @intToFloat(f32, (i+1))*f, o+@intToFloat(f32, (j+1))*f);
        }
    }
    gfx.endBatch();


    var i: usize = 0;

    gfx.setColor4(0.0, 0.0, 1.0, 0.5);
    gfx.startBatchLine();
    while (i < rays.seg_i0.len) : (i += 1) {
        if (i % 10 == 0) {
            var j = rays.seg_i0[i];
            const j0 = rays.seg_i1[i];

            while (j <= j0) : (j += 1) {
                gfx.addLine(segments.x0[j]*f, o+segments.y0[j]*f,
                            segments.x1[j]*f, o+segments.y1[j]*f);
            }
        }
    }
    gfx.endBatch();

    const x = plr.getPosX();
    const y = plr.getPosY();
    const w = 0.1;
    const h = 0.5;
    const d = plr.getDir();
    gfx.setColor4(0.0, 1.0, 0.0, 0.7);
    gfx.drawTriangle((x-w*@sin(d))*f, o+(y+w*@cos(d))*f,
                     (x+h*@cos(d))*f, o+(y+h*@sin(d))*f,
                     (x+w*@sin(d))*f, o+(y-w*@cos(d))*f);
}

pub fn showScene() void {

    const win_h = @intToFloat(f32, gfx.getWindowHeight());
    var i: usize = 0;

    gfx.startBatchLine();
    while (i < rays.seg_i0.len) : (i += 1) {

        const j0 = rays.seg_i0[i];
        const j1 = rays.seg_i1[i];
        var j = @intCast(i32, j1);

        const s_dx0 = segments.x1[j0] - segments.x0[j0];
        const s_dy0 = segments.y1[j0] - segments.y0[j0];
        const ang_0 = std.math.atan2(f32, s_dy0, s_dx0) - plr.getDir();

        while (j >= j0) : (j -= 1){
            // Use an optical pleasing combination of the natural lense effect due
            // to a "point" camera and the "straight line correction". This results
            // in little dynamic changes when rotating the camera (instead of just)
            // moving the still scene on the screen) as well as the non-linearity
            // that differentiates it from polygons
            var d = segments.d[@intCast(usize, j)];
            d *= (0.5 + 0.5 * @cos(ang_0));
            if (d < 0.5) d = 0.5;

            const d_norm = 2 / d; // At 2m distance, the walls are screen filling (w.r.t. height)
            const h_half = win_h * d_norm * 0.5;

            const tilt = -win_h * plr.getTilt();
            const shift = win_h * plr.getPosZ() / (d+1e-3);

            if (j == j1) {
                gfx.setColor3(d_norm, d_norm, d_norm);
            } else {
                gfx.setColor4(d_norm*0.5, d_norm*0.5, d_norm, 0.3);
            }
            gfx.addLine(@intToFloat(f32, i), win_h*0.5-h_half + shift + tilt,
                        @intToFloat(f32, i), win_h*0.5+h_half + shift + tilt);
        }
    }
    gfx.endBatch();
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const segments_max = 10;

const log_ray = std.log.scoped(.ray);

// var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
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
};

var perf_gfx_alloc: stats.Performance = undefined;

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

    // Allocate memory for segment data
    segments.x0 = allocator.alloc(f32, n * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.x0);
    segments.y0 = allocator.alloc(f32, n * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.y0);
    segments.x1 = allocator.alloc(f32, n * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.x1);
    segments.y1 = allocator.alloc(f32, n * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.y1);
    segments.d = allocator.alloc(f32, n * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.d);
}

fn freeMemory() void {
    allocator.free(rays.seg_i0);
    allocator.free(rays.seg_i1);
    allocator.free(segments.x0);
    allocator.free(segments.y0);
    allocator.free(segments.x1);
    allocator.free(segments.y1);
    allocator.free(segments.d);
}

fn reallocRaysOnChange() !void {
    if (gfx.getWindowWidth() != rays.seg_i0.len) {
        perf_gfx_alloc.startMeasurement();
        log_ray.debug("Reallocating memory for ray data", .{});

        freeMemory();
        try allocMemory(gfx.getWindowWidth());

        perf_gfx_alloc.stopMeasurement();
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
    traceSingleSegment0(d_x, d_y, s_i, r_i);
}

fn traceSingleSegment0(d_x0: f32, d_y0: f32, s_i: usize, r_i: usize) void {
    const Axis = enum { x, y };

    var a: Axis = .y;           // primary axis for stepping
    var sign_x: f32 = 1;
    var sign_y: f32 = 1;
    var is_wall: bool = false;
    var s_x = segments.x0[s_i]; // segment pos x
    var s_y = segments.y0[s_i]; // segment pos y
    var d_x = d_x0;             // direction x
    var d_y = d_y0;             // direction y
    const g_x = d_y/d_x;        // gradient/derivative of the segment for direction x
    const g_y = d_x/d_y;        // gradient/derivative of the segment for direction y

    if (@fabs(d_x) > @fabs(d_y)) a = .x;
    if (d_x < 0) sign_x = -1;
    if (d_y < 0) sign_y = -1;

    while (!is_wall) {
        if (sign_x == 1) {
            d_x = @trunc(s_x+1) - s_x;
        } else {
            d_x = @ceil(s_x-1) - s_x;
        }
        if (sign_y == 1) {
            d_y = @trunc(s_y+1) - s_y;
        } else {
            d_y = @ceil(s_y-1) - s_y;
        }

        var o_x: f32 = 0;
        var o_y: f32 = 0;
        var is_contact_on_x_axis: bool = false;
        if (a == .x) {
            if (@fabs(d_x * g_x) < @fabs(d_y)) {
                s_x += d_x;
                s_y += @fabs(d_x * g_x) * sign_y;
                if (sign_x == -1) o_x = -0.5;
                // default: is_contact_on_y_axis = false;
            } else {
                s_x += @fabs(d_y * g_y) * sign_x;
                s_y += d_y;
                if (sign_y == -1) o_y = -0.5;
                is_contact_on_x_axis = true;
            }
        } else { // (a == .y)
            if (@fabs(d_y * g_y) < @fabs(d_x)) {
                s_x += @fabs(d_y * g_y) * sign_x;
                s_y += d_y;
                if (sign_y == -1) o_y = -0.5;
                is_contact_on_x_axis = true;
            } else {
                s_x += d_x;
                s_y += @fabs(d_x * g_x) * sign_y;
                if (sign_x == -1) o_x = -0.5;
                // default: is_contact_on_y_axis = false;
            }
        }

        const m_y = @floatToInt(usize, s_y+o_y);
        const m_x = @floatToInt(usize, s_x+o_x);
        const m_v = @intToEnum(map.Cell, map.get()[m_y][m_x]);

        switch (m_v) {
            map.Cell.wall => {
                is_wall = true;
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
            },
            map.Cell.mirror => {
                if (is_contact_on_x_axis) {
                    d_y = -d_y0;
                    d_x = d_x0;
                } else {
                    d_x = -d_x0;
                    d_y = d_y0;
                }
                // Only prepare next segment if not already the last segment of the
                // last ray!
                if (s_i+1 < rays.seg_i0.len * segments_max) {
                    segments.x0[s_i+1] = s_x;
                    segments.y0[s_i+1] = s_y;
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
                // Just be sure to stay below the maximum segment number per ray
                if ((rays.seg_i1[r_i] - rays.seg_i0[r_i]) < segments_max-1) {
                    rays.seg_i1[r_i] += 1;
                    traceSingleSegment0(d_x, d_y, s_i+1, r_i);
                }
                is_wall = true;
            },
            map.Cell.glass => {
                d_x = d_x0;
                d_y = d_y0;
                // Only prepare next segment if not already the last segment of the
                // last ray!
                if (s_i+1 < rays.seg_i0.len * segments_max) {
                    segments.x0[s_i+1] = s_x;
                    segments.y0[s_i+1] = s_y;
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
                if ((rays.seg_i1[r_i] - rays.seg_i0[r_i]) < segments_max-1) {
                    rays.seg_i1[r_i] += 1;
                    traceSingleSegment0(d_x, d_y, s_i+1, r_i);
                }
                is_wall = true;
            },
            else => {}
        }
    }
}
