const std = @import("std");
const builtin = @import("builtin");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");
const gfx = @import("gfx_rw.zig");
// const rw_gui = @import("rw_gui.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const plr = @import("player.zig");
const rc = @import("raycaster.zig");
const stats = @import("stats.zig");
// const sim = @import("sim.zig");

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
    try gfx_core.init();
    defer gfx_core.deinit();

    try gfx.init();
    defer gfx.deinit();
    try rc.init();
    defer rc.deinit();

    gfx_core.setFpsTarget(cfg.gfx.fps_target);
    input.setWindow(gfx_core.getWindow());
    try input.init();

    //--------------
    //   Load map
    //--------------
    var prf_map = try stats.PerFrameTimerBuffered(1).init();
    prf_map.start();
    try map.init();
    defer map.deinit();
    prf_map.stop();
    std.log.info("Map loading took {d:.2}ms", .{prf_map.getAvgAllMs()});

    //----------------
    //   Init gui
    //----------------
    // try rw_gui.init();
    // try rw_gui.setHelpMessage(help_message);
    // defer rw_gui.deinit();

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
    // try sim.init();
    // defer sim.deinit();
    // var sim_thread: std.Thread = undefined;

    // if (cfg.multithreading) sim_thread = try std.Thread.spawn(.{}, sim.run, .{});


    var hsr_thread: std.Thread = undefined;
    if (builtin.os.tag == .linux) {
        const gfx_hsr= @import("gfx_hsr.zig");
        gfx_hsr.init();
        hsr_thread = try std.Thread.spawn(.{}, gfx_hsr.readEvent, .{});
    }

    while (gfx_core.isWindowOpen()) {

        prf_in.start();
        input.processInputs(gfx_core.getFPS());
        prf_in.stop();

        adjustFovOnAspectChange(); // Polling for now, should be event triggered

        prf_rc.start();
        try rc.processRays(cfg.multithreading);
        prf_rc.stop();

        // if (!cfg.multithreading) sim.step();

        prf_ren.start();
        prf_ren_scene.start();
        rc.createScene();
        prf_ren_scene.stop();
        prf_ren_map.start();
        rc.createMap();
        prf_ren_map.stop();
        prf_ren_frame.start();
        try gfx.renderFrame();
        prf_ren_frame.stop();
        prf_ren_sim.start();
        // try sim.createScene();
        prf_ren_sim.stop();

        prf_ren_gui.start();
        // try rw_gui.updatePerformanceStats(prf_fps.getAvgBufMs(),
        //                                   prf_idle.getAvgBufMs(),
        //                                   prf_in.getAvgBufMs(),
        //                                   prf_rc.getAvgBufMs(),
        //                                   prf_ren.getAvgBufMs(),
        //                                   prf_ren_scene.getAvgBufMs(),
        //                                   prf_ren_frame.getAvgBufMs(),
        //                                   prf_ren_map.getAvgBufMs(),
        //                                   prf_ren_gui.getAvgBufMs(),
        //                                   prf_ren_sim.getAvgBufMs(),
        //                                   sim.getAvgBufMs());
        var cur_x: f64 = 0;
        var cur_y: f64 = 0;
        input.getCursorPos(&cur_x, &cur_y);
        // try rw_gui.process(@floatCast(cur_x), @floatCast(cur_y),
        //                    input.isMouseButtonLeftPressed(), input.getMouseState().wheel);
        prf_ren_gui.stop();

        prf_ren.stop();

        input.resetStates();

        prf_idle.start();
        try gfx_core.finishFrame();
        prf_idle.stop();
        prf_fps.stop();
        prf_fps.start();

        if (builtin.os.tag == .linux) {
            const gfx_hsr = @import("gfx_hsr.zig");
            if (gfx_hsr.is_reload_triggered.value) {
                try gfx.reloadShaders();
                gfx_hsr.is_reload_triggered.value = false;
            }
        }
    }

    if (builtin.os.tag == .linux) {
        const gfx_hsr = @import("gfx_hsr.zig");
        gfx_hsr.rmWatch();
        @atomicStore(bool, &gfx_hsr.is_running, false, .Unordered);
        hsr_thread.join();
    }

    // sim.stop();
    // if (cfg.multithreading) sim_thread.join();

    showPerformanceStats(prf_fps.getAvgAllMs(),
                         prf_idle.getAvgAllMs(),
                         prf_in.getAvgAllMs(),
                         prf_rc.getAvgAllMs(),
                         prf_ren.getAvgAllMs(),
                         prf_ren_scene.getAvgAllMs(),
                         prf_ren_frame.getAvgAllMs(),
                         prf_ren_map.getAvgAllMs(),
                         prf_ren_gui.getAvgAllMs(),
                         prf_ren_sim.getAvgAllMs(),
                         0.0);
                         // sim.getAvgAllMs());

}

fn adjustFovOnAspectChange() void {
    const aspect = gfx_core.getAspect();
    if (cfg.gfx.scale_by == .room_height) {
        plr.setFOV(cfg.gfx.room_height*aspect*std.math.degreesToRadians(f32, 22.5));
        cfg.gfx.player_fov = std.math.degreesToRadians(f32, plr.getFOV());
    } else { // scale_by == player_fov
        plr.setFOV(std.math.degreesToRadians(f32, cfg.gfx.player_fov));
        cfg.gfx.room_height = plr.getFOV()/(aspect*std.math.degreesToRadians(f32, 22.5));
    }
}

fn printUsage() void {
    std.debug.print(help_message ++ "\n", .{});
}

inline fn showPerformanceStats(fps: f64, idle: f64, in: f64, rayc: f64, ren: f64,
                               ren_scene: f64, ren_frame: f64, ren_map: f64, ren_gui: f64,
                               ren_sim: f64, simulation: f64) void {

        std.log.info(
           "\nFrametime:    {d:.2}ms\n" ++
           "  Idle:       {d:.2}ms\n" ++
           "  Input:      {d:.2}ms\n" ++
           "  Raycasting: {d:.2}ms\n" ++
           "  Rendering:  {d:.2}ms\n" ++
           "    Scene:    {d:.2}ms\n" ++
           "    Frame:    {d:.2}ms\n" ++
           "    Map:      {d:.2}ms\n" ++
           "    Gui:      {d:.2}ms\n" ++
           "    Sim:      {d:.2}ms\n" ++
           "Sim-Thread:   {d:.2}ms\n" ++
           "(@{d:.0}Hz => {d:.2}ms @{d:.0}Hz)",
           .{fps, idle, in, rayc, ren, ren_scene, ren_frame, ren_map, ren_gui, ren_sim, simulation,
             // sim.timing.getFpsTarget(), simulation*sim.timing.getFpsTarget()/cfg.gfx.fps_target,
             100, simulation*100/cfg.gfx.fps_target,
             cfg.gfx.fps_target}
        );
}

const help_message = "=====================\n" ++
            " Welcome to Rayworld \n" ++
            "=====================\n\n" ++
            "GENERAL\n" ++
            "  F1:     this help\n" ++
            "  F2:     debug info\n" ++
            "  CTRL-E: toggle edit mode (preparation for map editor)\n" ++
            "  CTRL-R: manually reload shaders\n" ++
            "  Q:      quit\n" ++
            "MOVEMENT\n" ++
            "  Use mouse to turn/look around\n" ++
            "  WASD:   move\n" ++
            "  E/C:    move up/down (debug)\n" ++
            "SIMULATION\n" ++
            "  Cursor Keys (l/r/u/d): move map\n" ++
            "  M:      toggle system map\n" ++
            "  H:      toggle station hook\n" ++
            "SIMULATION TIMING\n" ++
            "  P:      toggle pause\n" ++
            "  F3/F4:  zoom (out/in)\n" ++
            "  F5/F6:  time acceleration (decrease/increase x10)\n" ++
            "  F7/F8:  time acceleration thread frequency\n" ++
            "          - 100Hz base x factor\n" ++
            "          - automatically reduced if load too high";
