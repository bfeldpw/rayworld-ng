const std = @import("std");

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn move(x: f32, y: f32) void {
    pos_x += x;
    pos_y += y;
    std.log.debug("Pos: ({d:.1}, {d:.1})", .{pos_x, pos_y});
}

pub fn moveX(x: f32) void {
    pos_x += x;
    std.log.debug("Pos: ({d:.1}, {d:.1})", .{pos_x, pos_y});
}

pub fn moveY(y: f32) void {
    pos_y += y;
    std.log.debug("Pos: ({d:.1}, {d:.1})", .{pos_x, pos_y});
}

pub fn turn(d: f32) void {
    dir += d;
    if (dir < 0.0) dir += 2.0*std.math.pi;
    if (dir > 2.0*std.math.pi) dir -= 2.0*std.math.pi;
    std.log.debug("Dir: {d:.2}", .{dir});
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

var dir: f32 = 0.0;
var fov: u32 = 90.0;
var pos_x: f32 = 10.0;
var pos_y: f32 = 10.0;
