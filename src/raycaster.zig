const std = @import("std");
const gfx = @import("graphics.zig");
const map = @import("map.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    rays = try allocator.alloc(f32, 640);
}

pub fn deinit() void {
    allocator.free(rays);
    const leaked = gpa.deinit();
    if (leaked) log_ray.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn showMap() !void {
    try reallocRaysOnChange();

    const m = map.get();
    const map_cells_y = @intToFloat(f32, map.get().len);
    const map_vis_y = 0.9;
    const win_h = @intToFloat(f32, gfx.getWindowHeight());
    const f = win_h * map_vis_y / map_cells_y; // scale factor cell -> px
    const o = win_h-f*map_cells_y; // y-offset for map drawing in px

    for (m) |y,j| {
        for (y) |x,i| {
            if (x == 0) {
                gfx.setColor4(0.2, 0.2, 0.2, 0.7);
            } else {
                gfx.setColor4(1.0, 1.0, 1.0, 0.7);
            }
            gfx.drawQuad(@intToFloat(f32, i)*f, o+@intToFloat(f32, j)*f,
                         @intToFloat(f32, (i+1))*f, o+@intToFloat(f32, (j+1))*f);
        }
    }

    const x = plr.getPosX();
    const y = plr.getPosY();

    var i: @TypeOf(gfx.getWindowWidth()) = 0;
    var angle: f32 = plr.getDir() - 0.5*plr.getFOV();
    const inc_angle: f32 = plr.getFOV() / @intToFloat(f32, gfx.getWindowWidth());

    const l = 10.0;

    gfx.setColor4(0.0, 0.0, 1.0, 0.5);
    while (i <= gfx.getWindowWidth()) : (i += 1) {
        angle += inc_angle;
        if (i % 10 == 0) {
            gfx.drawLine(x*f, o+y*f, (x+l*@cos(angle))*f, o+(y+l*@sin(angle))*f);
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

pub fn processRays() void {
    const m = map.get();
    _ = m;

    // var i: @TypeOf(gfx.getWindowWidth()) = 0;
    // var angle: f32 = plr.getDir() - 0.5*plr.getFOV();
    // const inc_angle: f32 = plr.getFOV() / @intToFloat(f32, gfx.getWindowWidth());

    // const l = 10.0;

    // gfx.setColor3(0.0, 0.0, 1.0);
    // while (i <= gfx.getWindowWidth()) : (i += 1) {
    //     angle += inc_angle;
    //     gfx.drawLine(plr.getPosX(), plr.getPosY(),
    //                  plr.getPosX()+l*@cos(angle), plr.getPosY()+l*@sin(angle));
    // }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_ray = std.log.scoped(.ray);

// var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var rays: []f32 = undefined;

fn reallocRaysOnChange() !void {
    if (gfx.getWindowWidth() != rays.len) {
        allocator.free(rays);
        rays = try allocator.alloc(f32, gfx.getWindowWidth());
        log_ray.debug("Window resized, changing number of rays -> {}", .{rays.len});
    }
}
