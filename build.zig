const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const glfw = @import("3rdparty/mach-glfw/build.zig");

    const exe = b.addExecutable("rayworld-ng", "src/main.zig");
    // exe.addIncludePath("3rdparty/zgl");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackage(glfw.pkg);
    // glfw.link(b, exe, .{}) catch |e| {
    //     std.log.err("Linker error: {}", .{e});
    // };
    exe.linkSystemLibrary("gl");
    try glfw.link(b, exe, .{});
    exe.install();
    exe.emit_docs = .emit;

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
