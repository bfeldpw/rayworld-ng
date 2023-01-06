const std = @import("std");
const gfx = @import("graphics.zig");
const map = @import("map.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    rays.x = try allocator.alloc(f32, 640);
    rays.y = try allocator.alloc(f32, 640);
}

pub fn deinit() void {
    allocator.free(rays.x);
    allocator.free(rays.y);

    const leaked = gpa.deinit();
    if (leaked) log_ray.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn processRays() !void {
    try reallocRaysOnChange();

    const m = map.get();
    const x = plr.getPosX();
    const y = plr.getPosY();
    const l = 10.0;

    var i: @TypeOf(gfx.getWindowWidth()) = 0;
    var angle: f32 = plr.getDir() - 0.5*plr.getFOV();
    const inc_angle: f32 = plr.getFOV() / @intToFloat(f32, gfx.getWindowWidth());

    while (i < rays.x.len) : (i += 1) {
        rays.x[i] = x+l*@cos(angle);
        rays.y[i] = y+l*@sin(angle);

        var r_xi = @floatToInt(usize, rays.x[i]);
        var r_yi = @floatToInt(usize, rays.y[i]);
        if (r_xi < 0) r_xi = 0;
        if (r_yi < 0) r_yi = 0;
        if (r_xi > 19) r_xi = 19;
        if (r_yi > 17) r_yi = 17;

        if (m[r_yi][r_xi] == 1) {
            rays.x[i] -= 3.0;
        }

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

    for (m) |y,j| {
        for (y) |x,i| {
            if (x == 0) {
                gfx.setColor4(0.2, 0.2, 0.2, 0.3);
            } else {
                gfx.setColor4(1.0, 1.0, 1.0, 0.3);
            }
            gfx.drawQuad(@intToFloat(f32, i)*f, o+@intToFloat(f32, j)*f,
                         @intToFloat(f32, (i+1))*f, o+@intToFloat(f32, (j+1))*f);
        }
    }

    const x = plr.getPosX();
    const y = plr.getPosY();

    var i: @TypeOf(gfx.getWindowWidth()) = 0;

    gfx.setColor4(0.0, 0.0, 1.0, 0.5);
    while (i < rays.x.len) : (i += 1) {
        if (i % 10 == 0) {
            gfx.drawLine(x*f, o+y*f, rays.x[i]*f, o+rays.y[i]*f);
        }
    }

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

    while (i < rays.x.len) : (i += 1) {
        const d_x = rays.x[i] - x;
        const d_y = rays.y[i] - y;
        var d = @sqrt(d_x*d_x + d_y*d_y);
        if (d < 0.5) d = 0.5;

        const win_h = @intToFloat(f32, gfx.getWindowHeight());
        const h_half = win_h * 2.0 / d * 0.5;

        gfx.setColor3(2.0 / d, 2.0 / d, 2.0 / d);
        gfx.drawVerticalLine(@intToFloat(f32, i), win_h*0.5-h_half, win_h*0.5+h_half);
    }
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
};

/// Struct of array instanciation to store ray data. Memory allocation is done
/// in @init function
var rays = RayData{
    .x = undefined,
    .y = undefined,
};

fn reallocRaysOnChange() !void {
    if (gfx.getWindowWidth() != rays.x.len) {
        allocator.free(rays.x);
        allocator.free(rays.y);
        rays.x = try allocator.alloc(f32, gfx.getWindowWidth());
        rays.y = try allocator.alloc(f32, gfx.getWindowWidth());
        log_ray.debug("Window resized, changing number of rays -> {}", .{rays.x.len});
    }
}
