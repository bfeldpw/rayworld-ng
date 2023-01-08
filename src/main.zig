const std = @import("std");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const rc = @import("raycaster.zig");
const stats = @import("perf_stats.zig");

pub const scope_levels = [_]std.log.ScopeLevel{
    // .{ .scope = .gfx, .level = .debug },
    .{ .scope = .input, .level = .info },
    .{ .scope = .plr, .level = .info },
    // .{ .scope = .stats, .level = .info },
};

pub fn main() !void {
    try gfx.init();
    defer gfx.deinit();
    try rc.init();
    defer rc.deinit();

    gfx.setFrequency(60.0);
    input.setWindow(gfx.getWindow());
    input.init();

    var perf_fps = try stats.Performance.init("Frametime");
    var perf_in = try stats.Performance.init("Input");
    var perf_rc = try stats.Performance.init("Raycasting");
    var perf_ren = try stats.Performance.init("Rendering");

    while (gfx.isWindowOpen()) {

        perf_in.startMeasurement();
        input.processInputs();
        perf_in.stopMeasurement();

        perf_rc.startMeasurement();
        try rc.processRays();
        perf_rc.stopMeasurement();

        perf_ren.startMeasurement();
        rc.showScene();
        rc.showMap();
        perf_ren.stopMeasurement();

        gfx.finishFrame();
        perf_fps.stopMeasurement();
        perf_fps.startMeasurement();
    }
    perf_fps.printStats();
    perf_in.printStats();
    perf_rc.printStats();
    perf_ren.printStats();
}
