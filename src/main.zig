const std = @import("std");
const c = @import("c.zig").c;
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const plr = @import("player.zig");
const rc = @import("raycaster.zig");
const stats = @import("stats.zig");

const multithreading = true;

const ScalePreference = enum {
    room_height,
    player_fov,
};

var scale_by = ScalePreference.room_height;
var room_height: f32 = 2.0; // meter
var player_fov: f32 = 90; // degrees

pub const std_options = struct {
    pub const log_scope_levels = &[_]std.log.ScopeLevel{
        // .{ .scope = .gfx, .level = .debug },
        .{ .scope = .input, .level = .info },
        // .{ .scope = .map, .level = .debug },
        .{ .scope = .plr, .level = .info },
        // .{ .scope = .stats, .level = .info },
    };
};

pub fn main() !void {
    try gfx.init();
    defer gfx.deinit();
    try rc.init();
    defer rc.deinit();

    gfx.setFrequencyTarget(60.0);
    input.setWindow(gfx.getWindow());
    input.init();

    var perf_map = try stats.Performance.init("Map");
    perf_map.startMeasurement();
    try map.init();
    defer map.deinit();
    perf_map.stopMeasurement();

    var perf_fps = try stats.Performance.init("Frametime");
    var perf_in = try stats.Performance.init("Input");
    var perf_rc = try stats.Performance.init("Raycasting");
    var perf_ren = try stats.Performance.init("Rendering");

    while (gfx.isWindowOpen()) {

        perf_in.startMeasurement();
        input.processInputs(gfx.getFPS());
        perf_in.stopMeasurement();

        adjustFovOnAspectChange(); // Polling for now, should be event triggered

        perf_rc.startMeasurement();
        try rc.processRays(multithreading);
        // var rc_thread = try std.Thread.spawn(.{}, rc.processRays, .{multithreading});
        // rc_thread.join();
        perf_rc.stopMeasurement();

        perf_ren.startMeasurement();
        rc.createScene();
        try gfx.renderFrame();
        rc.createMap();
        perf_ren.stopMeasurement();

        try gfx.finishFrame();
        perf_fps.stopMeasurement();
        perf_fps.startMeasurement();

    }
    perf_map.printStats();
    perf_fps.printStats();
    perf_in.printStats();
    perf_rc.printStats();
    perf_ren.printStats();
}

fn adjustFovOnAspectChange() void {
    const aspect = gfx.getAspect();
    if (scale_by == .room_height) {
        plr.setFOV(room_height*aspect*std.math.degreesToRadians(f32, 22.5));
        player_fov = std.math.degreesToRadians(f32, plr.getFOV());
    } else { // scale_by == player_fov
        plr.setFOV(std.math.degreesToRadians(f32, player_fov));
        room_height = plr.getFOV()/(aspect*std.math.degreesToRadians(f32, 22.5));
    }
}
