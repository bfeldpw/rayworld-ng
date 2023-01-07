const std = @import("std");
const gfx = @import("graphics.zig");
const map = @import("map.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    // ToDo: Free if out of memory occurs for an allocation
    log_ray.debug("Allocating memory for ray data", .{});
    rays.x = try allocator.alloc(f32, 640);
    rays.y = try allocator.alloc(f32, 640);
    rays.poc_x = try allocator.alloc(f32, 640);
    rays.poc_y = try allocator.alloc(f32, 640);
}

pub fn deinit() void {
    allocator.free(rays.x);
    allocator.free(rays.y);
    allocator.free(rays.poc_x);
    allocator.free(rays.poc_y);

    const leaked = gpa.deinit();
    if (leaked) log_ray.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn processRays() !void {
    try reallocRaysOnChange();

    const p_x = plr.getPosX();
    const p_y = plr.getPosY();

    var i: usize = 0;
    var angle: f32 = plr.getDir() - 0.5*plr.getFOV();
    const inc_angle: f32 = plr.getFOV() / @intToFloat(f32, rays.x.len);

    while (i < rays.x.len) : (i += 1) {
        rays.x[i] = p_x;
        rays.y[i] = p_y;

        traceSingleRay(angle, i);

        angle += inc_angle;
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

    const x = plr.getPosX();
    const y = plr.getPosY();

    var i: @TypeOf(gfx.getWindowWidth()) = 0;

    gfx.setColor4(0.0, 0.0, 1.0, 0.5);
    gfx.startBatchLine();
    while (i < rays.x.len) : (i += 1) {
        if (i % 10 == 0) {
            gfx.addLine(x*f, o+y*f, rays.x[i]*f, o+rays.y[i]*f);
        }
    }
    gfx.endBatch();

    const w = 0.1;
    const h = 0.5;
    const d = plr.getDir();
    gfx.setColor4(0.0, 1.0, 0.0, 0.7);
    gfx.drawTriangle((x-w*@sin(d))*f, o+(y+w*@cos(d))*f,
                     (x+h*@cos(d))*f, o+(y+h*@sin(d))*f,
                     (x+w*@sin(d))*f, o+(y-w*@cos(d))*f);
}

pub fn showScene() void {
    const x = plr.getPosX();
    const y = plr.getPosY();

    var i: @TypeOf(gfx.getWindowWidth()) = 0;

    gfx.startBatchLine();
    while (i < rays.x.len) : (i += 1) {
        const d_x = rays.x[i] - x;
        const d_y = rays.y[i] - y;
        var d = @sqrt(d_x*d_x + d_y*d_y);// * @cos(ang);

        if (d < 0.5) d = 0.5;

        // Draw the scene with a very naive vertical ambient occlusion approach
        const win_h = @intToFloat(f32, gfx.getWindowHeight());
        const d_norm = 2 / d; // At 2m distance, the walls are screen filling (w.r.t. height)
        const h_half = win_h * d_norm * 0.5;
        const ao_darkening_0 = 0.6;         // outer color fading factor
        const ao_darkening_1 = 0.9;         // inner color fading factor
        const ao_height_0 = 0.9;            // outer color fading height
        const ao_height_1 = 0.8;            // inner color fading height

        // The vertical line consists of 5 parts. While the center part has the
        // base color, outer lines produce a darkening towards the upper and
        // lower edges. Since OpenGL interpolation is done linearily, it is two
        // line segments on top and bottom to hide the linear behaviour a little
        // This might be easily replaced by GL core profile and a simple shader
        gfx.addLineColor3(@intToFloat(f32, i), win_h*0.5-h_half, @intToFloat(f32, i), win_h*0.5-h_half*ao_height_0,
                          d_norm * ao_darkening_0, d_norm * ao_darkening_0, d_norm * ao_darkening_0,
                          d_norm * ao_darkening_1, d_norm * ao_darkening_1, d_norm * ao_darkening_1);
        gfx.addLineColor3(@intToFloat(f32, i), win_h*0.5-h_half*ao_height_0, @intToFloat(f32, i), win_h*0.5-h_half*ao_height_1,
                          d_norm * ao_darkening_1, d_norm * ao_darkening_1, d_norm * ao_darkening_1,
                          d_norm, d_norm, d_norm);
        gfx.setColor3(d_norm, d_norm, d_norm);
        gfx.addLine(@intToFloat(f32, i), win_h*0.5-h_half*ao_height_1, @intToFloat(f32, i), win_h*0.5+h_half*ao_height_1);
        gfx.addLineColor3(@intToFloat(f32, i), win_h*0.5+h_half*ao_height_1, @intToFloat(f32, i), win_h*0.5+h_half*ao_height_0,
                          d_norm, d_norm, d_norm,
                          d_norm * ao_darkening_1, d_norm * ao_darkening_1, d_norm * ao_darkening_1);
        gfx.addLineColor3(@intToFloat(f32, i), win_h*0.5+h_half*ao_height_0, @intToFloat(f32, i), win_h*0.5+h_half,
                          d_norm * ao_darkening_1, d_norm * ao_darkening_1, d_norm * ao_darkening_1,
                          d_norm * ao_darkening_0, d_norm * ao_darkening_0, d_norm * ao_darkening_0);
    }
    gfx.endBatch();
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_ray = std.log.scoped(.ray);

// var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

/// Struct of arrays (SOA) to store ray data
const RayData = struct {
    x: []f32,
    y: []f32,
    poc_x: []f32, // point of collision (within cell, -1 if wall on y-axis)
    poc_y: []f32, // point of collision (within cell, -1 if wall on x-axis)
};

/// Struct of array instanciation to store ray data. Memory allocation is done
/// in @init function
var rays = RayData{
    .x = undefined,
    .y = undefined,
    .poc_x = undefined,
    .poc_y = undefined,
};

fn reallocRaysOnChange() !void {
    if (gfx.getWindowWidth() != rays.x.len) {
        log_ray.debug("Reallocating memory for ray data", .{});
        allocator.free(rays.x);
        allocator.free(rays.y);
        allocator.free(rays.poc_x);
        allocator.free(rays.poc_y);
        rays.x = try allocator.alloc(f32, gfx.getWindowWidth());
        rays.y = try allocator.alloc(f32, gfx.getWindowWidth());
        rays.poc_x = try allocator.alloc(f32, gfx.getWindowWidth());
        rays.poc_y = try allocator.alloc(f32, gfx.getWindowWidth());
        log_ray.debug("Window resized, changing number of rays -> {}", .{rays.x.len});
    }
}

fn traceSingleRay(angle: f32, r_i: usize) void {
    const Axis = enum { x, y };

    var a: Axis = .y;           // primary axis for stepping
    var sign_x: f32 = 1;
    var sign_y: f32 = 1;
    var is_wall: bool = false;
    var d_x = @cos(angle);      // direction x
    var d_y = @sin(angle);      // direction y
    var r_x = rays.x[r_i];      // ray pos x
    var r_y = rays.y[r_i];      // ray pos y
    const g_x = d_y/d_x;        // gradient/derivative of the ray for direction x
    const g_y = d_x/d_y;        // gradient/derivative of the ray for direction y

    if (@fabs(d_x) > @fabs(d_y)) a = .x;
    if (d_x < 0) sign_x = -1;
    if (d_y < 0) sign_y = -1;

    while (!is_wall) {
        if (sign_x == 1) {
            d_x = @trunc(r_x+1) - r_x;
        } else {
            d_x = @ceil(r_x-1) - r_x;
        }
        if (sign_y == 1) {
            d_y = @trunc(r_y+1) - r_y;
        } else {
            d_y = @ceil(r_y-1) - r_y;
        }

        var o_x: f32 = 0;
        var o_y: f32 = 0;
        if (a == .x) {
            if (@fabs(d_x * g_x) < @fabs(d_y)) {
                r_x += d_x;
                r_y += @fabs(d_x * g_x) * sign_y;
                if (sign_x == -1) o_x = -0.5;
            } else {
                r_x += @fabs(d_y * g_y) * sign_x;
                r_y += d_y;
                if (sign_y == -1) o_y = -0.5;
            }
        } else { // (a == .y)
            if (@fabs(d_y * g_y) < @fabs(d_x)) {
                r_x += @fabs(d_y * g_y) * sign_x;
                r_y += d_y;
                if (sign_y == -1) o_y = -0.5;
            } else {
                r_x += d_x;
                r_y += @fabs(d_x * g_x) * sign_y;
                if (sign_x == -1) o_x = -0.5;
            }
        }

        if (map.get()[@floatToInt(usize, r_y+o_y)][@floatToInt(usize, r_x+o_x)] == 1) is_wall = true;
    }
    rays.x[r_i] = r_x;
    rays.y[r_i] = r_y;
}
