const std = @import("std");
const zstbi = @import("libs/zstbi/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rayworld-ng",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.install();

    const zstbi_pkg = zstbi.Package.build(b, target, optimize, .{});
    exe.addModule("zstbi", zstbi_pkg.zstbi);
    zstbi_pkg.link(exe);

    exe.linkLibC();
    exe.linkSystemLibrary("gl");
    exe.linkSystemLibrary("glfw");
    if (optimize == std.builtin.Mode.ReleaseSafe) {
        exe.strip = true;
    }
    exe.install();
    exe.emit_docs = .emit;

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
