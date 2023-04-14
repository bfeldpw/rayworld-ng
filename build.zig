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

    const zstbi_pkg = zstbi.Package.build(b, target, optimize, .{});
    exe.addModule("zstbi", zstbi_pkg.zstbi);
    zstbi_pkg.link(exe);

    exe.addIncludePath("src");
    exe.addCSourceFile("src/stb_implementation.c", &[_][]u8{""});
    exe.linkLibC();
    exe.linkSystemLibrary("gl");
    exe.linkSystemLibrary("glfw");
    if (optimize == std.builtin.Mode.ReleaseSafe) {
        exe.strip = true;
    }
    b.installArtifact(exe);
    exe.emit_docs = .emit;

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/test.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addIncludePath("src");
    unit_tests.addCSourceFile("src/stb_implementation.c", &[_][]u8{""});
    unit_tests.linkLibC();
    unit_tests.linkSystemLibrary("gl");
    unit_tests.linkSystemLibrary("glfw");
    unit_tests.addModule("zstbi", zstbi_pkg.zstbi);
    zstbi_pkg.link(unit_tests);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
