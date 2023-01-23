const std = @import("std");
const c = @import("c.zig").c;
const gfx = @import("graphics.zig");
const img = @import("image_loader.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const rc = @import("raycaster.zig");
const stats = @import("stats.zig");

const multithreading = true;

pub const std_options = struct {
    pub const log_scope_levels = &[_]std.log.ScopeLevel{
        // .{ .scope = .gfx, .level = .debug },
        .{ .scope = .input, .level = .info },
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

    var perf_img = try stats.Performance.init("Texture");
    perf_img.startMeasurement();
    try loadResources();
    perf_img.stopMeasurement();

    try map.init();
    defer map.deinit();

    var perf_fps = try stats.Performance.init("Frametime");
    var perf_in = try stats.Performance.init("Input");
    var perf_rc = try stats.Performance.init("Raycasting");
    var perf_ren = try stats.Performance.init("Rendering");

    while (gfx.isWindowOpen()) {

        perf_in.startMeasurement();
        input.processInputs(gfx.getFPS());
        perf_in.stopMeasurement();

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
    perf_img.printStats();
    perf_fps.printStats();
    perf_in.printStats();
    perf_rc.printStats();
    perf_ren.printStats();
}

fn loadResources() !void {
    img.init();
    defer img.deinit();

    const image = try img.loadImage("resource/metal_01_1024_bfeld.jpg");
    const tex = gfx.createTexture(image.width, image.height, &image.data);
    rc.setTex1024(tex);
    img.releaseImage();
}
