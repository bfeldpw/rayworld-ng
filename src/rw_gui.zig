const std = @import("std");
const gui = @import("gui.zig");
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx = @import("graphics.zig");
const input = @import("input.zig");
const sim = @import("sim.zig");

pub fn init() !void {

    fnt.init();
    try fnt.addFont("anka_b", "resource/AnkaCoder-C87-b.ttf");
    try fnt.addFont("anka_i", "resource/AnkaCoder-C87-i.ttf");
    try fnt.addFont("anka_r", "resource/AnkaCoder-C87-r.ttf");
    try fnt.addFont("anka_bi", "resource/AnkaCoder-C87-bi.ttf");
    try fnt.rasterise("anka_b", 32, gfx.getTextureId());

    var font_overlay: gui.ParamOverlay = .{.title = .{.text = "Font Idle Timers",
                                                      .col  = .{0.8, 1.0, 0.8, 0.8}},
                                           .width = 300,
                                           .height = 32.0 * (@intToFloat(f32, fnt.getIdByName().count()+1)),
                                           .is_centered = false,
                                           .is_enabled = false,
                                           .ll_x = 10.0,
                                           .ll_y = 10.0,
                                           .col = .{0.0, 1.0, 0.0, 0.2},
                                           };
    const text_widget: gui.TextWidget = .{.overlay = &font_overlay,
                                          .col = .{0.5, 1.0, 0.5, 0.8}};
    try gui.addOverlay("fnt_ovl", font_overlay);
    try gui.addTextWidget("fnt_ovl", "fnt_txt", text_widget);

    var prf_overlay: gui.ParamOverlay = .{.title = .{.text = "Performance Stats",
                                                     .col  = .{0.8, 1.0, 0.8, 0.8}},
                                          .width = 400,
                                          .height = 32.0 * 13,
                                          .is_centered = false,
                                          .is_enabled = false,
                                          .ll_x = 330.0,
                                          .ll_y = 10.0,
                                          .col = .{0.0, 1.0, 0.0, 0.2},
                                          .widget_type = .text,
                                          };
    const prf_widget: gui.TextWidget = .{.overlay = &prf_overlay,
                                         .col = .{0.5, 1.0, 0.5, 0.8}};
    try gui.addOverlay("prf_ovl", prf_overlay);
    try gui.addTextWidget("prf_ovl", "prf_txt", prf_widget);

    var help_overlay: gui.ParamOverlay = .{.title = .{.text = "Help",
                                                      .col = .{0.8, 1.0, 0.8, 0.8}},
                                           .width = 200,
                                           .height = 200,
                                           .is_enabled = false,
                                           .col = .{0.0, 1.0, 0.0, 0.2},
                                           .widget_type = .text,
                                           };
    const help_widget: gui.TextWidget = .{.overlay = &help_overlay,
                                          .text = "HelpMessage",
                                          .col = .{0.5, 1.0, 0.5, 0.8}};
    try gui.addOverlay("hlp_ovl", help_overlay);
    try gui.addTextWidget("hlp_ovl", "hlp_txt", help_widget);
}

pub fn deinit() void {
    gui.deinit();
    fnt.deinit();
    arena.deinit();
}

pub fn setHelpMessage(msg: []const u8) !void {
    const hlp_txt = try gui.getTextWidget("hlp_txt");
    hlp_txt.text = msg;
    const hlp_ovl = try gui.getOverlay("hlp_ovl");
    const s = try fnt.getTextSize(msg);
    hlp_ovl.width = s.w + hlp_ovl.frame[0] + hlp_ovl.frame[2];
    hlp_ovl.height = s.h + hlp_ovl.frame[1] + hlp_ovl.frame[3];
}

pub fn toggleEditMode() void {
    is_edit_mode_enabled = is_edit_mode_enabled != true;

    if (is_edit_mode_enabled) {
        gui.showCursor();
    } else {
        gui.hideCursor();
    }
}

pub fn updatePerformanceStats(fps: f64, idle: f64, in: f64, rayc: f64, ren: f64,
                              ren_scene: f64, ren_frame: f64, ren_map: f64, ren_gui: f64,
                              ren_sim: f64, simulation: f64) !void {
    const ovl = try gui.getOverlay("prf_ovl");
    if (ovl.is_enabled) {
        const prf_printout = try std.fmt.allocPrint(allocator,
           "Frametime:    {d:.2}ms\n" ++
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
           "(@{d:.0}Hz => {d:.2}ms @{d:.0}Hz) ",
           .{fps, idle, in, rayc, ren, ren_scene, ren_frame, ren_map, ren_gui, ren_sim, simulation,
             sim.timing.getFpsTarget(), simulation*sim.timing.getFpsTarget()/cfg.gfx.fps_target,
             cfg.gfx.fps_target}
        );

        const prf_overlay: gui.ParamOverlay = .{.title = .{.text = "Performance Stats",
                                                            .col  = .{0.8, 1.0, 0.8, 0.8}},
                                                 .width = 400,
                                                 .height = 32.0 * 13,
                                                 .is_centered = false,
                                                 .ll_x = 330.0,
                                                 .ll_y = 10.0,
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

pub fn process(x: f32, y: f32) void {
    gui.drawCursor(x, y);
}

var buffer: [cfg.fnt.font_atlas_limit * 256]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();
