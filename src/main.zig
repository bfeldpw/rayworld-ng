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

    fnt.init();
    defer fnt.deinit();
    try fnt.addFont("anka", "resource/AnkaCoder-r.ttf");
    try fnt.rasterise("anka", 16, gfx.getTextureId());
    try fnt.rasterise("anka", 32, gfx.getTextureId());
    try fnt.rasterise("anka", 64, gfx.getTextureId());
    try fnt.setFont("anka", 32);
    // std.log.debug("Text length of <Rayworld> = {d:.2}", .{fnt.getTextLength("Rayworld")});
    // fnt.setFont("anka", 16) catch |err| {
    //     std.log.debug("{}", .{err});
    // };
    // fnt.setFont("anka", 16) catch |err| {
    //     std.log.debug("{}", .{err});
    //     try fnt.rasterise("anka", 16, gfx.getTextureId());
    // };

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
        perf_rc.stopMeasurement();

        if (!cfg.multithreading) sim.step();

        perf_ren.startMeasurement();
        rc.createScene();
        try gfx.renderFrame();
        rc.createMap();
        try sim.createScene();
        try fnt.renderAtlas();
        try displayHelp();

        perf_ren.stopMeasurement();

        try gfx.finishFrame();
        perf_fps.stopMeasurement();
        perf_fps.startMeasurement();

    }

    sim.stop();
    if (cfg.multithreading) sim_thread.join();

    fnt.printIdleTimes();

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

const font_size_help_message_default = 32;
var font_size_help_message: f32 = font_size_help_message_default;
fn displayHelp() !void {
    if (input.getF1()) {
        try fnt.setFont("anka", font_size_help_message);
        var size = fnt.getTextSize(help_message);
        const h = @intToFloat(f32, gfx.getWindowHeight());
        const w = @intToFloat(f32, gfx.getWindowWidth());
        if (size.w > w or size.h > h) {
            if (font_size_help_message > 8) {
                font_size_help_message -= 8;
                try fnt.setFont("anka", font_size_help_message);
                size = fnt.getTextSize(help_message);
            }
        }
        if (size.w < 0.75*w and size.h < 0.75*h) {
            if (font_size_help_message < font_size_help_message_default) {
                font_size_help_message += 8;
                try fnt.setFont("anka", font_size_help_message);
                size = fnt.getTextSize(help_message);
            }
        }
        const b_w = (w-size.w) / 2;
        const b_h = (h-size.h) / 2;

        try gui.drawOverlay(.{.title = .{.is_enabled = false, .col = .{0.0, 1.0, 0.0, 0.8}},
                              .width = size.w+10,
                              .height = size.h+10,
                              .col = .{0.0, 1.0, 0.0, 0.2}});
        gfx.setColor4(0.0, 1.0, 0.0, 0.8);
        try fnt.setFont("anka", font_size_help_message);
        try fnt.renderText(help_message, b_w, b_h);
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
