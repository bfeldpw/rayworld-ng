const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx = @import("graphics.zig");
const rw_gui = @import("rw_gui.zig");
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

    //---------------------------------------------
    //   Intialise window and graphics and input
    //---------------------------------------------
    try gfx.init();
    defer gfx.deinit();
    try rc.init();
    defer rc.deinit();

    gfx.setFpsTarget(cfg.gfx.fps_target);
    input.setWindow(gfx.getWindow());
    input.init();

    //----------------
    //   Load fonts
    //----------------
    var prf_fnt = try stats.PerFrameTimerBuffered(1).init();
    prf_fnt.start();
    fnt.init();
    defer fnt.deinit();
    try fnt.addFont("anka_b", "resource/AnkaCoder-C87-b.ttf");
    try fnt.addFont("anka_i", "resource/AnkaCoder-C87-i.ttf");
    try fnt.addFont("anka_r", "resource/AnkaCoder-C87-r.ttf");
    prf_fnt.stop();
    std.log.info("Font loading took {d:.2}ms", .{prf_fnt.getAvgAllMs()});

    //--------------
    //   Load map
    //--------------
    var prf_map = try stats.PerFrameTimerBuffered(1).init();
    prf_map.start();
    try map.init();
    defer map.deinit();
    prf_map.stop();
    std.log.info("Map loading took {d:.2}ms", .{prf_map.getAvgAllMs()});

    //--------------------------------
    //   Prepare performance timers
    //--------------------------------
    const prf_buffer = cfg.gfx.fps_target; // 1s
    var prf_idle = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_ren = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_ren_scene = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_ren_frame = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_ren_gui = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_ren_map = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_ren_sim = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_fps = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_in = try stats.PerFrameTimerBuffered(prf_buffer).init();
    var prf_rc = try stats.PerFrameTimerBuffered(prf_buffer).init();

    //--------------------------------------
    //   Initialise background simulation
    //--------------------------------------
    try sim.init();
    defer sim.deinit();
    var sim_thread: std.Thread = undefined;

    if (cfg.multithreading) sim_thread = try std.Thread.spawn(.{}, sim.run, .{});

    while (gfx.isWindowOpen()) {

        prf_in.start();
        input.processInputs(gfx.getFPS());
        prf_in.stop();

        adjustFovOnAspectChange(); // Polling for now, should be event triggered

        prf_rc.start();
        try rc.processRays(cfg.multithreading);
        prf_rc.stop();

        if (!cfg.multithreading) sim.step();

        prf_ren.start();
        prf_ren_scene.start();
        rc.createScene();
        prf_ren_scene.stop();
        prf_ren_frame.start();
        try gfx.renderFrame();
        prf_ren_frame.stop();
        prf_ren_map.start();
        rc.createMap();
        prf_ren_map.stop();
        prf_ren_sim.start();
        try sim.createScene();
        prf_ren_sim.stop();

        prf_ren_gui.start();
        try rw_gui.displayFontStats();
        try rw_gui.displayPerformanceStats(prf_fps.getAvgBufMs(),
                                           prf_idle.getAvgBufMs(),
                                           prf_in.getAvgBufMs(),
                                           prf_rc.getAvgBufMs(),
                                           prf_ren.getAvgBufMs(),
                                           prf_ren_scene.getAvgBufMs(),
                                           prf_ren_frame.getAvgBufMs(),
                                           prf_ren_map.getAvgBufMs(),
                                           prf_ren_gui.getAvgBufMs(),
                                           prf_ren_sim.getAvgBufMs(),
                                           sim.getAvgBufMs());
        try rw_gui.displayHelp(help_message);
        prf_ren_gui.stop();

        prf_ren.stop();

        prf_idle.start();
        try gfx.finishFrame();
        prf_idle.stop();
        prf_fps.stop();
        prf_fps.start();

    }

    sim.stop();
    if (cfg.multithreading) sim_thread.join();
}

fn adjustFovOnAspectChange() void {
    const aspect = gfx.getAspect();
    if (cfg.gfx.scale_by == .room_height) {
        plr.setFOV(cfg.gfx.room_height*aspect*std.math.degreesToRadians(f32, 22.5));
        cfg.gfx.player_fov = std.math.degreesToRadians(f32, plr.getFOV());
    } else { // scale_by == player_fov
        plr.setFOV(std.math.degreesToRadians(f32, cfg.gfx.player_fov));
        cfg.gfx.room_height = plr.getFOV()/(aspect*std.math.degreesToRadians(f32, 22.5));
    }
}
var font_size_base: f32 = 32.0;

fn printUsage() void {
    std.debug.print(help_message, .{});
}

const help_message = "=====================\n" ++
            " Welcome to Rayworld \n" ++
            "=====================\n\n" ++
            "GENERAL\n" ++
            "  F1:    this help\n" ++
            "  F2:    debug info\n" ++
            "  Q:     quit\n" ++
            "MOVEMENT\n" ++
            "  Use mouse to turn/look around\n" ++
            "  WASD:  move\n" ++
            "  E/C:   move up/down (debug)\n" ++
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
            "         - automatically reduced if load too high\n\n";
