const std = @import("std");
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
    const opacity = 0.9;
    const m = map.get();
    const m_col = map.getColor();
    const map_cells_y = @intToFloat(f32, map.get().len);
    const map_vis_y = 0.3;
    const win_h = @intToFloat(f32, gfx.getWindowHeight());
    const f = win_h * map_vis_y / map_cells_y; // scale factor cell -> px
    const o = win_h-f*map_cells_y; // y-offset for map drawing in px

    gfx.startBatchQuads();
    for (m) |y,j| {
        for (y) |cell,i| {
            const c = m_col[j][i];
            switch (cell) {
                .floor => {
                    gfx.setColor4(0.2+0.1*c.r, 0.2+0.1*c.g, 0.2+0.1*c.b, opacity);
                },
                .wall, .mirror, .glass, .pillar => {
                    gfx.setColor4(0.3+0.3*c.r, 0.3+0.3*c.g, 0.3+0.3*c.b, opacity);
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
        if (i % 4 == 0) {
            var j = @intCast(i32, rays.seg_i1[i]);
            const j0 = rays.seg_i0[i];

            while (j >= j0) : (j -= 1) {
                const color_grade = 0.2*@intToFloat(f32, @intCast(usize, j)-j0);
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
    const map_col = map.getColor();

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
            const cell_col = map_col[segments.cell_y[k]][segments.cell_x[k]];

            var u_of_uv: f32 = 0;
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

            switch (segments.cell_type[k]) {
                .mirror => {
                    const i_attr_color = map.getAttributeColorIndex()[segments.cell_y[k]][segments.cell_x[k]];
                    const col_r = map.getAttributesColor(i_attr_color).col_r;
                    const col_g = map.getAttributesColor(i_attr_color).col_g;
                    const col_b = map.getAttributesColor(i_attr_color).col_b;
                    const opacity = map.getAttributesColor(i_attr_color).opacity;
                    const i_attr_canvas = map.getAttributeCanvasIndex()[segments.cell_y[k]][segments.cell_x[k]];
                    const canvas_top = map.getAttributesCanvas(i_attr_canvas).canvas_top;
                    const canvas_bottom = map.getAttributesCanvas(i_attr_canvas).canvas_bottom;
                    const canvas_opacity = map.getAttributesCanvas(i_attr_canvas).canvas_opacity;
                    const h_half_top = h_half*@mulAdd(f32, -2, canvas_top, 1); // h_half*(1-2*canvas_top);
                    const h_half_bottom = h_half*@mulAdd(f32, -2, canvas_bottom, 1); // h_half*(1-2*canvas_bottom);
                    const i_wall = map.getAttributeIndex()[segments.cell_y[k]][segments.cell_x[k]];
                    const tex_id = map.getAttributesWall()[i_wall].tex_id;
                    gfx.addVerticalLine(x, win_h*0.5 - h_half_top + shift_and_tilt,
                                           win_h*0.5 + h_half_bottom + shift_and_tilt,
                                        d_norm*col_r, d_norm*col_g, d_norm*col_b, opacity,
                                        depth_layer);
                    if (canvas_bottom+canvas_top > 0.0) {
                        // gfx.addVerticalTexturedLine(x, win_h*0.5-h_half + shift + tilt,
                        //                                win_h*0.5-h_half*mirror_height + shift + tilt,
                        gfx.addVerticalTexturedLine(x, win_h*0.5-h_half + shift_and_tilt,
                                               win_h*0.5-h_half_top + shift_and_tilt,
                                                u_of_uv, 0, canvas_top,
                                            d_norm*cell_col.r, d_norm*cell_col.g, d_norm*cell_col.b, canvas_opacity,
                                                depth_layer, tex_id);
                        // gfx.addVerticalTexturedLine(x, win_h*0.5+h_half + shift + tilt,
                        //                                win_h*0.5+h_half*mirror_height + shift + tilt,
                        gfx.addVerticalTexturedLine(x, win_h*0.5+h_half + shift_and_tilt,
                                            win_h*0.5+h_half_bottom + shift_and_tilt,
                                                    u_of_uv, 1, 1-canvas_bottom,
                                            d_norm*cell_col.r, d_norm*cell_col.g, d_norm*cell_col.b, canvas_opacity,
                                                    depth_layer, tex_id);
                    }
                },
                .glass => {
                    // gfx.addVerticalLine(x, win_h*0.5-h_half + shift_and_tilt,
                    //                     win_h*0.5+h_half + shift_and_tilt,
                    //                     d_norm*cell_col.r, d_norm*cell_col.g, d_norm*cell_col.b, cell_col.a,
                    //                     depth_layer);
                    const i_attr_color = map.getAttributeColorIndex()[segments.cell_y[k]][segments.cell_x[k]];
                    const col_r = map.getAttributesColor(i_attr_color).col_r;
                    const col_g = map.getAttributesColor(i_attr_color).col_g;
                    const col_b = map.getAttributesColor(i_attr_color).col_b;
                    const opacity = map.getAttributesColor(i_attr_color).opacity;
                    const i_attr_canvas = map.getAttributeCanvasIndex()[segments.cell_y[k]][segments.cell_x[k]];
                    const canvas_top = map.getAttributesCanvas(i_attr_canvas).canvas_top;
                    const canvas_bottom = map.getAttributesCanvas(i_attr_canvas).canvas_bottom;
                    const canvas_opacity = map.getAttributesCanvas(i_attr_canvas).canvas_opacity;
                    const h_half_top = h_half*@mulAdd(f32, -2, canvas_top, 1); // h_half*(1-2*canvas_top);
                    const h_half_bottom = h_half*@mulAdd(f32, -2, canvas_bottom, 1); // h_half*(1-2*canvas_bottom);
                    const i_wall = map.getAttributeIndex()[segments.cell_y[k]][segments.cell_x[k]];
                    const tex_id = map.getAttributesWall()[i_wall].tex_id;
                    gfx.addVerticalLine(x, win_h*0.5 - h_half_top + shift_and_tilt,
                                           win_h*0.5 + h_half_bottom + shift_and_tilt,
                                        d_norm*col_r, d_norm*col_g, d_norm*col_b, opacity,
                                        depth_layer);
                    if (canvas_bottom+canvas_top > 0.0) {
                        // gfx.addVerticalTexturedLine(x, win_h*0.5-h_half + shift + tilt,
                        //                                win_h*0.5-h_half*mirror_height + shift + tilt,
                        gfx.addVerticalTexturedLine(x, win_h*0.5-h_half + shift_and_tilt,
                                                       win_h*0.5-h_half_top + shift_and_tilt,
                                                    u_of_uv, 0, canvas_top,
                                                    d_norm*cell_col.r, d_norm*cell_col.g, d_norm*cell_col.b, canvas_opacity,
                                                    depth_layer, tex_id);
                        // gfx.addVerticalTexturedLine(x, win_h*0.5+h_half + shift + tilt,
                        //                                win_h*0.5+h_half*mirror_height + shift + tilt,
                        gfx.addVerticalTexturedLine(x, win_h*0.5+h_half + shift_and_tilt,
                                                       win_h*0.5+h_half_bottom + shift_and_tilt,
                                                    u_of_uv, 1, 1-canvas_bottom,
                                                    d_norm*cell_col.r, d_norm*cell_col.g, d_norm*cell_col.b, canvas_opacity,
                                                    depth_layer, tex_id);
                    }
                },
                else => {
                    // gfx.addVerticalTexturedLine(x, win_h*0.5-h_half*mirror_height + shift + tilt,
                    //                             win_h*0.5+h_half*mirror_height + shift + tilt,
                    const i_opacity = map.getAttributeIndex()[segments.cell_y[k]][segments.cell_x[k]];
                    const opacity = map.getAttributesWall()[i_opacity].opacity;
                    const tex_id = map.getAttributesWall()[i_opacity].tex_id;
                    // log_ray.debug("Tex-ID: {}", .{tex_id});

                    gfx.addVerticalTexturedLine(x, win_h*0.5-h_half + shift_and_tilt,
                                           win_h*0.5+h_half + shift_and_tilt,
                                                u_of_uv, 0, 1,
                                                d_norm*cell_col.r, d_norm*cell_col.g, d_norm*cell_col.b, opacity,
                                                // d_norm*cell_col.r, d_norm*cell_col.g, d_norm*cell_col.b, cell_col.a,
                                                depth_layer, tex_id);
                },
            }
            if (j == j0) {
                gfx.addVerticalLineAO(x, win_h*0.5-h_half+shift_and_tilt, win_h*0.5+h_half+shift_and_tilt,
                                      0, 0.5*d_norm, 0.4, depth_layer);
                break;
            }
        }
    }
}

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

var tex_4096: u32 = 0;
var tex_2048: u32 = 0;
var tex_1024: u32 = 0;
var tex_512: u32 = 0;
var tex_256: u32 = 0;
var tex_128: u32 = 0;
var tex_64: u32 = 0;

pub fn setTex4096(tex: u32) void {
    tex_4096 = tex;
}

pub fn setTex2048(tex: u32) void {
    tex_2048 = tex;
}

pub fn setTex1024(tex: u32) void {
    tex_1024 = tex;
}

pub fn setTex512(tex: u32) void {
    tex_512 = tex;
}

pub fn setTex256(tex: u32) void {
    tex_256 = tex;
}

pub fn setTex128(tex: u32) void {
    tex_128 = tex;
}

pub fn setTex64(tex: u32) void {
    tex_64 = tex;
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
    segments.cell_type = allocator.alloc(map.CellType, n * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.cell_type);
    segments.cell_x = allocator.alloc(usize, n * segments_max) catch |e| {
        log_ray.err("Allocation error ", .{});
        return e;
    };
    errdefer allocator.free(segments.cell_x);
    segments.cell_y = allocator.alloc(usize, n * segments_max) catch |e| {
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
    traceSingleSegment0(d_x, d_y, s_i, r_i, .floor, segments_max-1);
}

const Axis = enum { x, y };

fn traceSingleSegment0(d_x0: f32, d_y0: f32,
                       s_i: usize, r_i: usize,
                       c_prev: map.CellType, s_lim: u8) void {

    var is_wall: bool = false;
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

    while (!is_wall) {

        var o_x: f32 = 0;
        var o_y: f32 = 0;
        var contact_axis: Axis = .x;

        advanceToNextCell(&d_x, &d_y, &s_x, &s_y,
                          &o_x, &o_y, &sign_x, &sign_y,
                          &a, &contact_axis,
                          g_x, g_y);

        var m_y = @floatToInt(usize, s_y+o_y);
        if (m_y > map.get().len-1) m_y = map.get().len-1;
        var m_x = @floatToInt(usize, s_x+o_x);
        if (m_x > map.get()[0].len-1) m_x = map.get()[0].len-1;
        const m_v = map.get()[m_y][m_x];

        var cell_type_prev = c_prev;
        var finish_segment: bool = true;
        var prepare_next_segment: bool = true;

        // React to cell type
        var new_segments_limit: u8 = 0;
        switch (m_v) {
            .floor => {
                if (cell_type_prev == .glass) {
                    const n = 1.0/1.46;
                    const refl = std.math.asin(@as(f32,n));
                    if (contact_axis == .x) {
                        const alpha = std.math.atan2(f32, @fabs(d_x0), @fabs(d_y0));
                        // total inner reflection?
                        if (alpha > refl) {
                            d_y = -d_y0;
                            d_x = d_x0;
                            cell_type_prev = .glass;
                        } else {
                            const beta = std.math.asin(std.math.sin(alpha / n));
                            d_x = @sin(beta);
                            d_y = @cos(beta);
                            if (d_x0 < 0) d_x = -d_x;
                            if (d_y0 < 0) d_y = -d_y;
                            cell_type_prev = .floor;
                        }
                    } else { // contact_axis == .y
                        const alpha = std.math.atan2(f32, @fabs(d_y0), @fabs(d_x0));
                        // total inner reflection?
                        if (alpha > refl) {
                            d_y = d_y0;
                            d_x = -d_x0;
                            cell_type_prev = .glass;
                        } else {
                            const beta = std.math.asin(std.math.sin(alpha / n));
                            d_y = @sin(beta);
                            d_x = @cos(beta);
                            if (d_x0 < 0) d_x = -d_x;
                            if (d_y0 < 0) d_y = -d_y;
                            cell_type_prev = .floor;
                        }
                    }
                    finish_segment = true;
                    prepare_next_segment = true;
                    new_segments_limit = @min(s_lim, segments_max-1);
                } else {
                    finish_segment = false;
                    prepare_next_segment = false;
                    new_segments_limit = 0;
                    cell_type_prev = .floor;
                }
            },
            .wall => {
                if (contact_axis == .x) {
                    d_y = -d_y0;
                    d_x = d_x0;
                } else {
                    d_x = -d_x0;
                    d_y = d_y0;
                }

                finish_segment = true;
                prepare_next_segment = true;
                new_segments_limit = @min(s_lim, 2);
                cell_type_prev = .wall;
            },
            .mirror => {
                if (contact_axis == .x) {
                    d_y = -d_y0;
                    d_x = d_x0;
                } else {
                    d_x = -d_x0;
                    d_y = d_y0;
                }

                finish_segment = true;
                prepare_next_segment = true;
                new_segments_limit = @min(s_lim, segments_max-1);
                cell_type_prev = .mirror;
            },
            .glass => {
                const n = 1.46;
                if (cell_type_prev != .glass) {
                    if (contact_axis == .x) {
                        const alpha = std.math.atan2(f32, @fabs(d_x0), @fabs(d_y0));
                        const beta = std.math.asin(std.math.sin(alpha / n));
                        d_x = @sin(beta);
                        d_y = @cos(beta);
                        if (d_x0 < 0) d_x = -d_x;
                        if (d_y0 < 0) d_y = -d_y;
                    } else { // !is_contact_on_x_axis
                        const alpha = std.math.atan2(f32, @fabs(d_y0), @fabs(d_x0));
                        const beta = std.math.asin(std.math.sin(alpha / n));
                        d_y = @sin(beta);
                        d_x = @cos(beta);
                        if (d_x0 < 0) d_x = -d_x;
                        if (d_y0 < 0) d_y = -d_y;
                    }
                    finish_segment = true;
                    prepare_next_segment = true;
                    new_segments_limit = @min(s_lim, segments_max-1);
                } else {
                    finish_segment = false;
                    prepare_next_segment = false;
                    new_segments_limit = 0;
                }
                cell_type_prev = .glass;
            },
            .pillar => {
                // const e_x = @intToFloat(f32, m_x)+0.5 - plr.getPosX();
                // const e_y = @intToFloat(f32, m_y)+0.5 - plr.getPosY();
                const e_x = @intToFloat(f32, m_x)+0.5 - s_x;
                const e_y = @intToFloat(f32, m_y)+0.5 - s_y;
                // log_ray.debug("d_cx = {d:.2}, d_cy = {d:.2}", .{e_x, e_y});
                const e_norm_sqr = e_x*e_x+e_y*e_y;
                const c_a = e_x * d_x0 + d_y0 * e_y;
                const r = 0.3;
                const w = r*r - (e_norm_sqr - c_a*c_a);
                is_wall = false;
                if (w > 0) {
                    const d_p = c_a - @sqrt(w);
                    if (d_p > 0) {
                        segments.x1[s_i] = d_x0 * d_p;
                        segments.y1[s_i] = d_y0 * d_p;
                        segments.d[s_i] = d_p;
                        segments.cell_x[s_i] = m_x;
                        segments.cell_y[s_i] = m_y;
                        segments.cell_type[s_i] = m_v;

                        segments.x1[s_i] = s_x + d_x0 * d_p;
                        segments.y1[s_i] = s_y + d_y0 * d_p;

                        const s_x0 = segments.x0[s_i];
                        const s_y0 = segments.y0[s_i];
                        const s_dx = s_x - s_x0;
                        const s_dy = s_y - s_y0;
                        // Accumulate distances, if first segment, set
                        if (s_i > rays.seg_i0[r_i]) {
                            segments.d[s_i] = segments.d[s_i-1] + @sqrt(s_dx*s_dx + s_dy*s_dy) + d_p;
                        } else {
                            segments.d[s_i] = @sqrt(s_dx*s_dx + s_dy*s_dy) + d_p;
                        }
                        // finish_segment = false;
                        // prepare_next_segment = false;
                        is_wall = true;
                    }
                }
                cell_type_prev = .pillar;
                new_segments_limit = 0;
                finish_segment = false;
                prepare_next_segment = false;
            }
        }

        if (finish_segment == true) is_wall = true;
        // if there is any kind of contact and a the segment ends, save all
        // common data
        // if ((m_v != .floor or (m_v == .floor and c_prev == .glass)) and
        //         (!((m_v == .glass) and (c_prev == .glass)))) {
        if (finish_segment == true) {

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

            // if (m_v != .floor) is_wall = true;
            // if (m_v == .floor and c_prev == .glass) is_wall = true;
        }

        // Prepare next segment
        // if (m_v == .floor and c_prev != .glass) prepare_next_segment = false;
        // Only prepare next segment if not already the last segment of the
        // last ray!
        if (prepare_next_segment and s_i+1 < rays.seg_i0.len * segments_max) {
            segments.x0[s_i+1] = s_x;
            segments.y0[s_i+1] = s_y;
        }

        // Just be sure to stay below the maximum segment number per ray
        if ((rays.seg_i1[r_i] - rays.seg_i0[r_i]) < new_segments_limit) {
            rays.seg_i1[r_i] += 1;
            traceSingleSegment0(d_x, d_y, s_i+1, r_i, cell_type_prev, new_segments_limit);
        }
    }
}

inline fn advanceToNextCell(d_x: *f32, d_y: *f32,
                            s_x: *f32, s_y: *f32,
                            o_x: *f32, o_y: *f32,
                            sign_x: *f32, sign_y: *f32,
                            a: *Axis,
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

    if (a.* == .x) {
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
    } else { // (a == .y)
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
