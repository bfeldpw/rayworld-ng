const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx = @import("graphics.zig");
const gui = @import("gui.zig");
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

    var prf_fnt = try stats.PerFrameTimerBuffered(1).init();
    prf_fnt.start();
    fnt.init();
    defer fnt.deinit();
    try fnt.addFont("anka_b", "resource/AnkaCoder-C87-b.ttf");
    try fnt.addFont("anka_i", "resource/AnkaCoder-C87-i.ttf");
    try fnt.addFont("anka_r", "resource/AnkaCoder-C87-r.ttf");
    prf_fnt.stop();
    std.log.info("Font loading took {d:.2}ms", .{prf_fnt.getAvgAllMs()});

    var prf_map = try stats.PerFrameTimerBuffered(1).init();
    prf_map.start();
    try map.init();
    defer map.deinit();
    prf_map.stop();
    std.log.info("Map loading took {d:.2}ms", .{prf_map.getAvgAllMs()});

    var prf_idle = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_ren = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_ren_scene = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_ren_frame = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_ren_map = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_ren_sim = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_fps = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_in = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();
    var prf_rc = try stats.PerFrameTimerBuffered(cfg.gfx.fps_target).init();

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
        // try fnt.renderAtlas();
        try displayFontStats();
        try displayPerformanceStats(prf_fps.getAvgBufMs(),
                                    prf_idle.getAvgBufMs(),
                                    prf_in.getAvgBufMs(),
                                    prf_rc.getAvgBufMs(),
                                    prf_ren.getAvgBufMs(),
                                    prf_ren_scene.getAvgBufMs(),
                                    prf_ren_frame.getAvgBufMs(),
                                    prf_ren_map.getAvgBufMs());
        try displayHelp();

        prf_ren.stop();

        prf_idle.start();
        try gfx.finishFrame();
        prf_idle.stop();
        prf_fps.stop();
        prf_fps.start();

    }

    sim.stop();
    if (cfg.multithreading) sim_thread.join();

    fnt.printIdleTimes();

    std.log.info("Sim (@{d:.0}Hz): {d:.2}ms", .{sim.timing.getFpsTarget(), sim.getAvgAllMs()});
    std.log.info("Frametime:    {d:.2}ms", .{prf_fps.getAvgAllMs()});
    std.log.info("  Idle:         {d:.2}ms", .{prf_idle.getAvgAllMs()});
    std.log.info("  Input:        {d:.2}ms", .{prf_in.getAvgAllMs()});
    std.log.info("  Sim:          {d:.2}ms", .{sim.getAvgAllMs()});
    std.log.info("  Raycasting:   {d:.2}ms", .{prf_rc.getAvgAllMs()});
    std.log.info("  Rendering:    {d:.2}ms", .{prf_ren.getAvgAllMs()});
    std.log.info("    Sim:          {d:.2}ms", .{prf_ren_sim.getAvgAllMs()});
    std.log.info("    Scene:        {d:.2}ms", .{prf_ren_scene.getAvgAllMs()});
    std.log.info("    Frame:        {d:.2}ms", .{prf_ren_frame.getAvgAllMs()});
    std.log.info("    Map:          {d:.2}ms", .{prf_ren_map.getAvgAllMs()});
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
var buffer: [cfg.fnt.font_atlas_limit * 256]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();

// var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){}
//           else std.heap.GeneralPurposeAllocator(.{}){};
// const allocator = gpa.allocator();
fn displayFontStats() !void {
    if (input.getF2()) {
        const names = fnt.getIdByName();
        const timers = fnt.getTimerById();

        var iter = names.iterator();
        var timer_printout = std.ArrayList(u8).init(allocator);

        while (iter.next()) |v| {
            const name = v.key_ptr.*;
            var timer = timers.get(v.value_ptr.*).?;

            const tmp = try std.fmt.allocPrint(allocator,
                                               "{s}: {d:.2}s\n",
                                               .{name, 1.0e-9 * @intToFloat(f64, timer.read())});
            try timer_printout.appendSlice(tmp);
            allocator.free(tmp);

        }
        const font_overlay: gui.ParamOverlay = .{.title = .{.text = "Font Idle Timers",
                                                            .col  = .{0.8, 1.0, 0.8, 0.8}},
                                                 .width = 300,
                                                 .height = 32.0 * (@intToFloat(f32, fnt.getIdByName().count()+1)),
                                                 .is_centered = false,
                                                 .ul_x = 10.0,
                                                 .ul_y = 10.0,
                                                 .col = .{0.0, 1.0, 0.0, 0.2},
                                                 .overlay_type = .text,
                                                 };
        var text_widget: gui.TextWidget = .{.overlay = font_overlay,
                                            .text = timer_printout.items,
                                            .col = .{0.5, 1.0, 0.5, 0.8}};
        try gui.drawOverlay(&text_widget.overlay);
        timer_printout.deinit();
        fba.reset();
    }
}

fn displayPerformanceStats(fps: f64, idle: f64, in: f64, rayc: f64, ren: f64,
                           ren_scene: f64, ren_frame: f64, ren_map: f64) !void {
    if (input.getF2()) {
        const prf_printout = try std.fmt.allocPrint(allocator,
           "Frametime:    {d:.2}ms\n" ++
           "  Idle:       {d:.2}ms\n" ++
           "  Input:      {d:.2}ms\n" ++
           "  Raycasting: {d:.2}ms\n" ++
           "  Rendering:  {d:.2}ms\n" ++
           "    Scene:    {d:.2}ms\n" ++
           "    Frame:    {d:.2}ms\n" ++
           "    Map:      {d:.2}ms\n",
            .{fps, idle, in, rayc, ren, ren_scene, ren_frame, ren_map}
        );

        const prf_overlay: gui.ParamOverlay = .{.title = .{.text = "Performance Stats",
                                                            .col  = .{0.8, 1.0, 0.8, 0.8}},
                                                 .width = 400,
                                                 .height = 32.0 * 9,
                                                 .is_centered = false,
                                                 .ul_x = 330.0,
                                                 .ul_y = 10.0,
                                                 .col = .{0.0, 1.0, 0.0, 0.2},
                                                 .overlay_type = .text,
                                                 };
        var text_widget: gui.TextWidget = .{.overlay = prf_overlay,
                                            .text = prf_printout,
                                            .col = .{0.5, 1.0, 0.5, 0.8}};
        try gui.drawOverlay(&text_widget.overlay);
        fba.reset();
    }
}

const font_size_help_message_default = 32;
var font_size_help_message: f32 = font_size_help_message_default;

fn displayHelp() !void {
    if (input.getF1()) {
        try fnt.setFont("anka_r", font_size_help_message);
        var size = fnt.getTextSize(help_message);
        const h = @intToFloat(f32, gfx.getWindowHeight());
        const w = @intToFloat(f32, gfx.getWindowWidth());
        if (size.w > w or size.h > h) {
            if (font_size_help_message > 8) {
                font_size_help_message -= 8;
                try fnt.setFont("anka_r", font_size_help_message);
                size = fnt.getTextSize(help_message);
            }
        }
        if (size.w < 0.75*w and size.h < 0.75*h) {
            if (font_size_help_message < font_size_help_message_default) {
                font_size_help_message += 8;
                try fnt.setFont("anka_r", font_size_help_message);
                size = fnt.getTextSize(help_message);
            }
        }

        const help_overlay: gui.ParamOverlay = .{.title = .{.is_enabled = false,
                                                            .col = .{0.0, 1.0, 0.0, 0.8}},
                                                 .width = size.w+10,
                                                 .height = size.h+10,
                                                 .col = .{0.0, 1.0, 0.0, 0.2},
                                                 .overlay_type = .text,
                                                 };
        var text_widget: gui.TextWidget = .{.overlay = help_overlay,
                                            .text = help_message,
                                            .col = .{0.5, 1.0, 0.5, 0.8}};
        try gui.drawOverlay(&text_widget.overlay);
    }
}

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
