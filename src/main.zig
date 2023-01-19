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

    var perf_img = try stats.Performance.init("Texture");
    perf_img.startMeasurement();
    try loadResources();
    perf_img.stopMeasurement();

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

    // try img.loadImage("resource/wall_4096_dbg.bmp");
    // const img_0 = img.getImage();
    // const tex_0 = gfx.createTexture(img_0.w, img_0.h, &img_0.rgb);
    // rc.setTex4096(tex_0);
    // img.releaseImage();
    // try img.loadImage("resource/wall_2048.bmp");
    // const img_1 = img.getImage();
    // const tex_1 = gfx.createTexture(img_1.w, img_1.h, &img_1.rgb);
    // rc.setTex2048(tex_1);
    // img.releaseImage();
    try img.loadImage("resource/wall_1024.bmp");
    const img_2 = img.getImage();
    const tex_2 = gfx.createTexture(img_2.w, img_2.h, &img_2.rgb);
    rc.setTex1024(tex_2);
    img.releaseImage();
    // try img.loadImage("resource/wall_512_dbg.bmp");
    // const img_3 = img.getImage();
    // const tex_3 = gfx.createTexture(img_3.w, img_3.h, &img_3.rgb);
    // rc.setTex512(tex_3);
    // img.releaseImage();
    // try img.loadImage("resource/wall_256_dbg.bmp");
    // const img_4 = img.getImage();
    // const tex_4 = gfx.createTexture(img_4.w, img_4.h, &img_4.rgb);
    // rc.setTex256(tex_4);
    // img.releaseImage();
    // try img.loadImage("resource/wall_128_dbg.bmp");
    // const img_5 = img.getImage();
    // const tex_5 = gfx.createTexture(img_5.w, img_5.h, &img_5.rgb);
    // rc.setTex128(tex_5);
    // img.releaseImage();
    // try img.loadImage("resource/wall_64_dbg.bmp");
    // const img_6 = img.getImage();
    // const tex_6 = gfx.createTexture(img_6.w, img_6.h, &img_6.rgb);
    // rc.setTex64(tex_6);
    // img.releaseImage();
}
