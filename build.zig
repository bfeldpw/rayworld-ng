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
    const zstbi_pkg = zstbi.package(b, target, optimize, .{});
    zstbi_pkg.link(exe);

    exe.addIncludePath(.{.path = "src"});
    exe.addCSourceFile(.{
        .file = .{ .path = "src/stb_implementation.c" },
        .flags = &.{
            "-std=c99",
            "-fno-sanitize=undefined",
            "-g",
            "-O0",
        },
    });
    exe.linkLibC();
    exe.linkSystemLibrary("gl");
    exe.linkSystemLibrary("glew");
    exe.linkSystemLibrary("glfw");
    if (optimize == std.builtin.Mode.ReleaseSafe) {
        exe.strip = true;
    }
    b.installArtifact(exe);

    // b.installDirectory(.{
    //     .source_dir = exe.getEmittedDocs(),
    //     .install_dir = .prefix,
    //     .install_subdir = "doc",
    // });

    const exe_gl_test = b.addExecutable(.{
        .name = "gl_test",
        .root_source_file = .{ .path = "src/gl_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_gl_test.addIncludePath(.{.path = "src"});
    exe_gl_test.addCSourceFile(.{
        .file = .{ .path = "src/stb_implementation.c" },
        .flags = &.{
            "-std=c99",
            "-fno-sanitize=undefined",
            "-g",
            "-O0",
        },
    });
    exe_gl_test.linkLibC();
    exe_gl_test.linkSystemLibrary("gl");
    exe_gl_test.linkSystemLibrary("glew");
    exe_gl_test.linkSystemLibrary("glfw");
    if (optimize == std.builtin.Mode.ReleaseSafe) {
        exe_gl_test.strip = true;
    }
    b.installArtifact(exe_gl_test);
    // exe.emit_docs = .emit;

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

    unit_tests.addIncludePath(.{.path = "src"});
    unit_tests.addCSourceFile(.{
        .file = .{ .path = "src/stb_implementation.c" },
        .flags = &.{
            "-std=c99",
            "-fno-sanitize=undefined",
            "-g",
            "-O0",
        },
    });
    unit_tests.linkLibC();
    unit_tests.linkSystemLibrary("gl");
    unit_tests.linkSystemLibrary("glew");
    unit_tests.linkSystemLibrary("glfw");
    // unit_tests.addModule("zstbi", zstbi_pkg.zstbi);
    zstbi_pkg.link(unit_tests);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
