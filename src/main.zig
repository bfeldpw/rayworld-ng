const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const plr = @import("player.zig");
const rc = @import("raycaster.zig");
const stats = @import("stats.zig");
const sim = @import("sim.zig");

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

    printUsage();

    try gfx.init();
    defer gfx.deinit();
    try rc.init();
    defer rc.deinit();

    gfx.setFpsTarget(cfg.gfx.fps_target);
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

    try sim.init();
    defer sim.deinit();
    var sim_thread: std.Thread = undefined;

    if (cfg.multithreading) sim_thread = try std.Thread.spawn(.{}, sim.run, .{});

    while (gfx.isWindowOpen()) {

        perf_in.startMeasurement();
        input.processInputs(gfx.getFPS());
        perf_in.stopMeasurement();

        adjustFovOnAspectChange(); // Polling for now, should be event triggered

        perf_rc.startMeasurement();
        try rc.processRays(cfg.multithreading);
        // var rc_thread = try std.Thread.spawn(.{}, rc.processRays, .{multithreading});
        // rc_thread.join();
        perf_rc.stopMeasurement();

        if (!cfg.multithreading) sim.step();

        perf_ren.startMeasurement();
        rc.createScene();
        try gfx.renderFrame();
        rc.createMap();
        sim.createScene();
        perf_ren.stopMeasurement();

        try gfx.finishFrame();
        perf_fps.stopMeasurement();
        perf_fps.startMeasurement();

    }

    sim.stop();
    if (cfg.multithreading) sim_thread.join();

    perf_map.printStats();
    perf_fps.printStats();
    perf_in.printStats();
    perf_rc.printStats();
    perf_ren.printStats();
}

fn adjustFovOnAspectChange() void {
    const aspect = gfx.getAspect();
    if (cfg.gfx.scale_by == .room_height) {
        plr.setFOV(cfg.gfx.room_height*aspect*std.math.degreesToRadians(f32, 22.5));
        cfg.gfx.player_fov = std.math.degreesToRadians(f32, plr.getFOV());
    } else { // scale_by == player_fov
        plr.setFOV(std.math.degreesToRadians(f32, cfg.player_fov));
        cfg.gfx.room_height = plr.getFOV()/(aspect*std.math.degreesToRadians(f32, 22.5));
    }
}

fn printUsage() void {
    std.debug.print("\n Welcome to Rayworld \n" ++
                    "=====================\n" ++
                    "MOVEMENT\n" ++
                    "  Use mouse to turn/look around\n" ++
                    "  WASD: move\n" ++
                    "  E/C:  to move up/down (debug)\n" ++
                    "SIMULATION\n" ++
                    "  Cursor Keys (l/r/u/d): move map\n" ++
                    "  M:     toggle system map\n" ++
                    "  H:     toggle station hook\n" ++
                    "SIMULATION TIMING\n" ++
                    "  P:     toggle pause\n" ++
                    "  F3/F4: zoom (out/in)\n" ++
                    "  F5/F6: time acceleration (decrease/increase x10)\n" ++
                    "  F7/F8: time acceleration thread frequency\n" ++
                    "         - 100Hz base x factor\n" ++
                    "         - automatically reduced if load too high\n\n", .{});
}
