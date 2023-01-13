const std = @import("std");
const c = @import("c.zig").c;
const gfx = @import("graphics.zig");
const img = @import("image_loader.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const rc = @import("raycaster.zig");
const stats = @import("perf_stats.zig");

const multithreading = true;

pub const scope_levels = [_]std.log.ScopeLevel{
    // .{ .scope = .gfx, .level = .debug },
    .{ .scope = .input, .level = .info },
    .{ .scope = .plr, .level = .info },
    // .{ .scope = .stats, .level = .info },
};

pub fn main() !void {
    try gfx.init();
    defer gfx.deinit();
    try rc.init();
    defer rc.deinit();

    gfx.setFrequency(60.0);
    input.setWindow(gfx.getWindow());
    input.init();

    img.init();
    defer img.deinit();

    var perf_img = try stats.Performance.init("Texture");
    perf_img.startMeasurement();

    try img.loadImage("resource/wall_1024.bmp");
    // img.releaseImage();
    // try img.loadImage("resource/wall_64.bmp");

    perf_img.stopMeasurement();

    const img_0 = img.getImage();
    const tex = gfx.createTexture(img_0.w, img_0.h, &img_0.rgb);
    _ = tex;
    img.releaseImage();
    // const tex = img.initDrawTest();

    map.init();

    var perf_fps = try stats.Performance.init("Frametime");
    var perf_in = try stats.Performance.init("Input");
    var perf_rc = try stats.Performance.init("Raycasting");
    var perf_ren = try stats.Performance.init("Rendering");

    while (gfx.isWindowOpen()) {

        perf_in.startMeasurement();
        input.processInputs();
        perf_in.stopMeasurement();

        perf_rc.startMeasurement();
        try rc.processRays(multithreading);
        perf_rc.stopMeasurement();

        perf_ren.startMeasurement();
        rc.showScene();
        rc.showMap();
        // img.processDrawTest(@intCast(c.GLuint, tex));
        perf_ren.stopMeasurement();

        gfx.finishFrame();
        perf_fps.stopMeasurement();
        perf_fps.startMeasurement();
    }
    perf_img.printStats();
    perf_fps.printStats();
    perf_in.printStats();
    perf_rc.printStats();
    perf_ren.printStats();
}
