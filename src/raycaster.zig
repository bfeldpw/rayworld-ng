const std = @import("std");
const gfx = @import("graphics.zig");
const map = @import("map.zig");
const plr = @import("player.zig");

pub fn processRays() void {
    const m = map.get();
    _ = m;

    // var i: @TypeOf(gfx.getWindowWidth()) = 0;
    // while (i <= gfx.getWindowWidth()) : (i += 1) {
    //     std.log.debug("{}", .{i});
    // }
}
