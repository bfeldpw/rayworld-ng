const std = @import("std");
const map = @import("map.zig");

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn move(m: f32) void {
    const p_x = pos_x + m * @cos(dir);
    const p_y = pos_y + m * @sin(dir);
    if (!isColliding(p_x, p_y, pos_x, pos_y)) {
        pos_x = p_x;
        pos_y = p_y;
    } else if (@fabs(m) > 0.05) {
        move(m * 0.9);
    }
}

pub fn moveUpDown(m: f32) void {
    pos_z += m;
}

pub fn strafe(m: f32) void {
    const p_x = pos_x + m * @sin(dir);
    const p_y = pos_y - m * @cos(dir);
    if (!isColliding(p_x, p_y, pos_x, pos_y)) {
        pos_x = p_x;
        pos_y = p_y;
    }
}

pub fn lookUpDown(t: f32) void {
    const tilt_max = 0.75;
    if (tilt + t < tilt_max and
        tilt + t > -tilt_max)
        tilt += t;

    const map_x: u32 = @intFromFloat(pos_x / map.getResolution());
    const map_y: u32 = @intFromFloat(pos_y / map.getResolution());
    const map_v = map.get()[map_y][map_x];
    log_plr.debug("pos: ({d:.1}, {d:.1}) / {d:.2}°, tilt: {d:.2} -> map={}",
                  .{pos_x, pos_y, std.math.radiansToDegrees(f32, dir), tilt, map_v});
}

pub fn turn(d: f32) void {
    dir -= d;
    if (dir < 0.0) dir += 2.0*std.math.pi;
    if (dir > 2.0*std.math.pi) dir -= 2.0*std.math.pi;

    const map_x: u32 = @intFromFloat(pos_x / map.getResolution());
    const map_y: u32 = @intFromFloat(pos_y / map.getResolution());
    const map_v = map.get()[map_y][map_x];
    log_plr.debug("pos: ({d:.1}, {d:.1}) / {d:.2}°, tilt: {d:.2} -> map={}",
                  .{pos_x, pos_y, std.math.radiansToDegrees(f32, dir), tilt, map_v});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn getDir() f32 {
    return dir;
}

pub inline fn getFOV() f32 {
    return fov;
}

pub inline fn getPosX() f32 {
    return pos_x;
}

pub inline fn getPosY() f32 {
    return pos_y;
}

pub inline fn getPosZ() f32 {
    return pos_z;
}

pub inline fn getTilt() f32 {
    return tilt;
}

pub inline fn setDir(d: f32) void {
    dir = d;
}

pub inline fn setFOV(f: f32) void {
    if (f != fov) {
        fov = f;
        log_plr.info("New setting, FOV = {d:.1}°", .{std.math.radiansToDegrees(f32, fov)});
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_plr = std.log.scoped(.plr);

var fov = std.math.degreesToRadians(f32, 90.0);
var dir: f32 = 0.0;
var radius: f32 = 0.25;
var pos_x: f32 = 2.5;
var pos_y: f32 = 2.5;
var pos_z: f32 = 0.3;
var tilt: f32 = 0.0;

fn isColliding(x: f32, y: f32, x0: f32, y0: f32) bool {

    const map_x: u32 = @intFromFloat(x / map.getResolution());
    const map_y: u32 = @intFromFloat(y / map.getResolution());

    const map_v = map.get()[map_y][map_x];
    log_plr.debug("pos: ({d:.1}, {d:.1}) / {d:.2}°, tilt: {d:.2} -> map={}",
                  .{pos_x, pos_y, std.math.radiansToDegrees(f32, dir), tilt, map_v});

    if (map_v == .wall_thin) {
        const wt = map.getWallThin(map_y, map_x);
        if (wt.axis == .x) {
            const y_c0 = y0 - @trunc(y0) + (@trunc(y0) - @trunc(y));
            // const y_c0 = y0 - @trunc(y0);
            const y_c = y - @trunc(y);
            if ((y_c + radius < wt.from and y_c0 + radius < wt.from) or
                (y_c > wt.to + radius and y_c0 > wt.to + radius)) return false;
            if ((y_c < wt.from and y_c0 > wt.to) or
                (y_c > wt.to and y_c0 < wt.from)) {
                return true;
            }
        } else { // if (wt.axis == .y)
            const x_c0 = x0 - @trunc(x0) + (@trunc(x0) - @trunc(x));
            // const x_c0 = x0 - @trunc(x0);
            const x_c = x - @trunc(x);
            if ((x_c + radius < wt.from and x_c0 + radius < wt.from) or
                (x_c > wt.to + radius and  x_c0 > wt.to + radius)) return false;
            if ((x_c < wt.from and x_c0 > wt.to) or
                (x_c > wt.to and x_c0 < wt.from)) {
                return true;
            }
        }
    }
    if (map_v != .floor) {
        return true;
    } else {
        return false;
    }
}
