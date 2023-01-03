const std = @import("std");
const map = @import("map.zig");

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn move(m: f32) void {
    const p_x = pos_x + m * @cos(dir);
    const p_y = pos_y + m * @sin(dir);
    if (!isColliding(p_x, p_y)) {
        pos_x = p_x;
        pos_y = p_y;
    }
}

pub fn strafe(m: f32) void {
    const p_x = pos_x - m * @sin(dir);
    const p_y = pos_y + m * @cos(dir);
    if (!isColliding(p_x, p_y)) {
        pos_x = p_x;
        pos_y = p_y;
    }
}

pub fn turn(d: f32) void {
    dir += d;
    if (dir < 0.0) dir += 2.0*std.math.pi;
    if (dir > 2.0*std.math.pi) dir -= 2.0*std.math.pi;

    const map_x = @floatToInt(u32, pos_x) / map.getResolution();
    const map_y = @floatToInt(u32, pos_y) / map.getResolution();
    const map_v = map.get().*[map_x][map_y];
    log_plr.debug("Pos: ({d:.1}, {d:.1}) / {d:.2} -> map={}", .{pos_x, pos_y, dir, map_v});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub fn getDir() f32 {
    return dir;
}

pub fn getPosX() f32 {
    return pos_x;
}

pub fn getPosY() f32 {
    return pos_y;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_plr = std.log.scoped(.plr);

var dir: f32 = 0.0;
var fov: u32 = 90.0;
var pos_x: f32 = 2.5;
var pos_y: f32 = 2.5;

fn isColliding(x: f32, y: f32) bool {
    const map_x = @floatToInt(u32, x) / map.getResolution();
    const map_y = @floatToInt(u32, y) / map.getResolution();

    const map_v = map.get().*[map_x][map_y];
    log_plr.debug("Pos: ({d:.1}, {d:.1}) / {d:.2} -> map={}", .{pos_x, pos_y, dir, map_v});

    if (map_v != 0) {
        return true;
    } else {
        return false;
    }
}
