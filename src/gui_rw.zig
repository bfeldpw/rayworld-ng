const std = @import("std");
const gui = @import("gui.zig");
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx_core = @import("gfx_core.zig");
const gfx_base = @import("gfx_base.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const plr = @import("player.zig");
const sim = @import("sim.zig");

pub fn init() !void {

    try fnt.init();
    try gui.init();
    try fnt.addFont("anka_b", "resource/AnkaCoder-C87-b.ttf");
    try fnt.addFont("anka_i", "resource/AnkaCoder-C87-i.ttf");
    try fnt.addFont("anka_r", "resource/AnkaCoder-C87-r.ttf");
    try fnt.addFont("anka_bi", "resource/AnkaCoder-C87-bi.ttf");
    try fnt.rasterise("anka_b", 32, try gfx_core.genTexture());

    const font_overlay: gui.Overlay = .{.title = .{.text = "Font Idle Timers",
                                                   .col  = .{0.7, 1.0, 0.7, 0.8},
                                                   .font_size = 24},
                                        .width = 300,
                                        .height = 32.0 * (@as(f32, @floatFromInt(fnt.getIdByName().count() + 1))),
                                        .is_enabled = false,
                                        .ll_x = 10.0,
                                        .ll_y = 10.0,
                                        .col = .{0.0, 0.9, 0.0, 0.2},
                                        };
    const text_widget: gui.TextWidget = .{.col = .{0.5, 1.0, 0.5, 0.8},
                                          .font_size = 24};
    try gui.addOverlay("fnt_ovl", font_overlay);
    try gui.addTextWidget("fnt_ovl", "fnt_txt", text_widget);

    const prf_overlay: gui.Overlay = .{.title = .{.text = "Performance Stats",
                                                  .col  = .{0.7, 1.0, 0.7, 0.8},
                                                  .font_size = 24},
                                       .width = 400,
                                       .height = 32.0 * 13,
                                       .align_h = .right,
                                       .align_v = .top,
                                       .is_enabled = false,
                                       .ll_x = 330.0,
                                       .ll_y = 10.0,
                                       .col = .{0.0, 1.0, 0.0, 0.2},
                                       .widget_type = .text,
                                       };
    const prf_widget: gui.TextWidget = .{.col = .{0.5, 1.0, 0.5, 0.8},
                                         .font_size = 24};
    try gui.addOverlay("prf_ovl", prf_overlay);
    try gui.addTextWidget("prf_ovl", "prf_txt", prf_widget);

    const help_overlay: gui.Overlay = .{.title = .{.text = "Help",
                                                   .col  = .{0.7, 1.0, 0.7, 0.8}},
                                        .width = 500,
                                        .height = 200,
                                        .resize_mode = .auto,
                                        .align_h = .centered,
                                        .align_v = .centered,
                                        .is_enabled = false,
                                        .col = .{0.0, 1.0, 0.0, 0.2},
                                        .widget_type = .texture,
                                        };
    const help_widget: gui.TextWidget = .{.text = "HelpMessage",
                                          .col  = .{0.5, 1.0, 0.5, 0.8}};
    try gui.addOverlay("hlp_ovl", help_overlay);
    try gui.addTextWidget("hlp_ovl", "hlp_txt", help_widget);

    const map_overlay: gui.Overlay = .{.title = .{.text = "Map",
                                                  .col  = .{0.7, 1.0, 0.7, 0.8},
                                                  .is_enabled = false,
                                                  .font_size = 24},
                                       .width = 300,
                                       .height = 300,
                                       .align_h = .left,
                                       .align_v = .bottom,
                                       .resize_mode = .auto,
                                       .is_enabled = true,
                                       .ll_x = 10.0,
                                       .ll_y = 300.0,
                                       .col = .{1.0, 1.0, 1.0, 0.1},
                                       .frame = .{ 5, 5, 5, 5 },
                                      };
    const map_widget: gui.TextureWidget = .{.col = .{1.0, 1.0, 1.0, 0.8},
                                            .tex_id = 3,
                                            .tex_w = 300,
                                            .tex_h = 400};
    try gui.addOverlay("map_ovl", map_overlay);
    try gui.addTextureWidget("map_ovl", "map_tex", map_widget);

    const sys_map_overlay: gui.Overlay = .{.title = .{.text = "System Map",
                                                  .col  = .{0.7, 1.0, 0.7, 0.8},
                                                  .is_enabled = false,
                                                  .font_size = 24},
                                        .width = 300,
                                        .height = 300,
                                        .align_h = .right,
                                        .align_v = .bottom,
                                        .resize_mode = .auto,
                                        .is_enabled = true,
                                        .ll_x = 10.0,
                                        .ll_y = 300.0,
                                        .col = .{1.0, 1.0, 1.0, 0.1},
                                        .frame = .{ 5, 5, 5, 5 },
                                        };
    const sys_map_widget: gui.TextureWidget = .{.col = .{1.0, 1.0, 1.0, 0.8},
                                            .tex_id = 3,
                                            .tex_w = 400,
                                            .tex_h = 400};
    try gui.addOverlay("sys_map_ovl", sys_map_overlay);
    try gui.addTextureWidget("sys_map_ovl", "sys_map_tex", sys_map_widget);
}

pub fn deinit() void {
    gui.deinit();
    fnt.deinit();
    arena.deinit();
}

pub fn setHelpMessage(msg: []const u8) !void {
    const hlp_txt = try gui.getTextWidget("hlp_txt");
    hlp_txt.text = msg;
}

pub fn toggleEditMode() void {
    is_edit_mode_enabled = is_edit_mode_enabled != true;
    gui.toggleEditMode();
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
           "(@{d:.0}Hz => {d:.2}ms @{d:.0}Hz)\n\n" ++
           "Bytes buffered:  {}\n" ++
           "Draw calls:      {}\n" ++
           "FBO binds:       {}\n" ++
           "Shader switches: {}\n" ++
           "Texture binds:   {}\n" ++
           "Uniform updates: {}\n" ++
           "VBO binds:       {}",
           .{fps, idle, in, rayc, ren, ren_scene, ren_frame, ren_map, ren_gui, ren_sim, simulation,
             sim.timing.getFpsTarget(), simulation*sim.timing.getFpsTarget()/cfg.gfx.fps_target,
             cfg.gfx.fps_target,
             gfx_core.getStatsBytesBuffered(), gfx_core.getStatsDrawCalls(), gfx_core.getStatsFboBinds(),
             gfx_core.getStatsShaderProgramSwitches(), gfx_core.getStatsTextureBinds(), gfx_core.getStatsUniformUpdates(),
             gfx_core.getStatsVboBinds()}
        );

        const t = try gui.getTextWidget("prf_txt");
        t.text = prf_printout;
    }
}

pub fn process(x: f32, y: f32, mouse_l: bool, mouse_wheel: f32) !void {
    gfx_base.updateProjection(.PxyCuniF32,
                                0, @floatFromInt(gfx_core.getWindowWidth() - 1),
                                @floatFromInt(gfx_core.getWindowHeight() - 1), 0);
    gfx_base.updateProjection(.PxyTuvCuniF32,
                                0, @floatFromInt(gfx_core.getWindowWidth() - 1),
                                @floatFromInt(gfx_core.getWindowHeight() - 1), 0);
    gfx_base.updateProjection(.PxyTuvCuniF32Font,
                                0, @floatFromInt(gfx_core.getWindowWidth() - 1),
                                @floatFromInt(gfx_core.getWindowHeight() - 1), 0);

    try updateFontStats();
    try gui.processOverlays(x, y, mouse_l, mouse_wheel);

    // try fnt.renderAtlas();

    if (is_edit_mode_enabled) {
        try fnt.setFont("anka_bi", 48);
        const t = "EDIT MODE";
        const s = fnt.getTextSizeLine("EDIT MODE") catch {return;};
        try fnt.renderText(t, @as(f32, @floatFromInt(gfx_core.getWindowWidth()))-s.w-10, 0, 0.0,
                           1.0, 1.0, 0.0, 0.8);
        try gui.drawCursor(x, y);
    }
    {
        const ovl = try gui.getOverlay("hlp_ovl");
        if (input.getF1()) {
            ovl.is_enabled = true;
        } else {
            ovl.is_enabled = false;
        }
    }
    {
        const ovl_fnt = try gui.getOverlay("fnt_ovl");
        const ovl_prf = try gui.getOverlay("prf_ovl");
        if (input.getF2()) {
            ovl_fnt.is_enabled = true;
            ovl_prf.is_enabled = true;
        } else {
            ovl_fnt.is_enabled = false;
            ovl_prf.is_enabled = false;
        }
    }
    const ovl_map = try gui.getTextureWidget("map_tex");
    ovl_map.center_x = plr.getPosX() / map.getSizeX();
    ovl_map.center_y = plr.getPosY() / map.getSizeY();
    ovl_map.zoom = 0.4;

    _ = arena.reset(.retain_capacity);
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

var is_edit_mode_enabled: bool = false;

fn updateFontStats() !void {
    const ovl = try gui.getOverlay("fnt_ovl");
    if (ovl.is_enabled) {
        const names = fnt.getIdByName();
        const timers = fnt.getTimerById();

        var iter = names.iterator();
        var timer_printout = std.ArrayList(u8).init(allocator);

        while (iter.next()) |v| {
            const name = v.key_ptr.*;
            var timer = timers.get(v.value_ptr.*).?;

            const tmp = try std.fmt.allocPrint(allocator,
                                               "{s}: {d:.1}s\n",
                                               .{name, 1.0e-9 * @as(f64, @floatFromInt(timer.read()))});
            try timer_printout.appendSlice(tmp);
            allocator.free(tmp);

        }
        _ = timer_printout.pop(); // Remove last carriage return
        var t = try gui.getTextWidget("fnt_txt");
        t.text = try timer_printout.toOwnedSlice();
    }
}
