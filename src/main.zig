const std = @import("std");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const rc = @import("raycaster.zig");

pub fn main() !void {
    try gfx.init();
    defer gfx.deinit();

    gfx.setFrequency(60.0);
    const win = gfx.getWindow();
    input.setWindow(win);
    input.init();

    while (gfx.isWindowOpen()) {
        rc.castRays();
        input.processInputs();
        gfx.draw();
        gfx.finishFrame();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
