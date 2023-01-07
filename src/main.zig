const std = @import("std");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const rc = @import("raycaster.zig");

pub const scope_levels = [_]std.log.ScopeLevel{
    // .{ .scope = .gfx, .level = .debug },
    .{ .scope = .input, .level = .info },
    .{ .scope = .plr, .level = .info },
};

pub fn main() !void {
    try gfx.init();
    defer gfx.deinit();
    try rc.init();
    defer rc.deinit();

    gfx.setFrequency(60.0);
    input.setWindow(gfx.getWindow());
    input.init();

    while (gfx.isWindowOpen()) {
        input.processInputs();
        try rc.processRays();
        rc.showScene();
        rc.showMap();
        gfx.finishFrame();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
