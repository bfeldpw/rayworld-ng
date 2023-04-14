const std = @import("std");
const cfg = @import("config.zig");
const fnt = @import("font_manager.zig");
const gfx = @import("graphics.zig");
const gui = @import("gui.zig");
const input = @import("input.zig");
const sim = @import("sim.zig");

const font_size_help_message_default = 32;
var font_size_help_message: f32 = font_size_help_message_default;

pub fn displayFontStats() !void {
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
                                                 .ll_x = 10.0,
                                                 .ll_y = 10.0,
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

pub fn displayHelp(msg: []const u8) !void {
    if (input.getF1()) {
        try fnt.setFont("anka_r", font_size_help_message);
        var size = fnt.getTextSize(msg);
        const h = @intToFloat(f32, gfx.getWindowHeight());
        const w = @intToFloat(f32, gfx.getWindowWidth());
        if (size.w > w or size.h > h) {
            if (font_size_help_message > 8) {
                font_size_help_message -= 8;
                try fnt.setFont("anka_r", font_size_help_message);
                size = fnt.getTextSize(msg);
            }
        }
        if (size.w < 0.75*w and size.h < 0.75*h) {
            if (font_size_help_message < font_size_help_message_default) {
                font_size_help_message += 8;
                try fnt.setFont("anka_r", font_size_help_message);
                size = fnt.getTextSize(msg);
            }
        }

        const help_overlay: gui.ParamOverlay = .{.title = .{.text = "Help",
                                                            .col = .{0.8, 1.0, 0.8, 0.8}},
                                                 .width = size.w+10,
                                                 .height = size.h+10,
                                                 .col = .{0.0, 1.0, 0.0, 0.2},
                                                 .overlay_type = .text,
                                                 };
        var text_widget: gui.TextWidget = .{.overlay = help_overlay,
                                            .text = msg,
                                            .col = .{0.5, 1.0, 0.5, 0.8}};
        try gui.drawOverlay(&text_widget.overlay);
    }
}

pub fn displayPerformanceStats(fps: f64, idle: f64, in: f64, rayc: f64, ren: f64,
                               ren_scene: f64, ren_frame: f64, ren_map: f64, ren_gui: f64,
                               ren_sim: f64, simulation: f64) !void {
    if (input.getF2()) {
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

var buffer: [cfg.fnt.font_atlas_limit * 256]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
const allocator = fba.allocator();
