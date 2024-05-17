const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "rayworld-ng",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(b.path("libs"));
    exe.addCSourceFile(.{
        .file = b.path("libs/stb_image.c"),
        .flags = &.{
            "-std=c99",
            "-O3"
        }
    });
    exe.addIncludePath(b.path("src"));
    exe.addCSourceFile(.{
        .file = b.path("src/stb_implementation.c"),
        .flags = &.{
            "-std=c99",
            "-fno-sanitize=undefined",
            "-g",
            "-O0",
        },
    });
    exe.linkLibC();
    exe.linkSystemLibrary("glew");
    exe.linkSystemLibrary("glfw");
    // if (optimize == std.builtin.Mode.ReleaseSafe) {
    //     exe.strip = true;
    // }
    b.installArtifact(exe);

    // b.installDirectory(.{
    //     .source_dir = exe.getEmittedDocs(),
    //     .install_dir = .prefix,
    //     .install_subdir = "doc",
    // });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addIncludePath(b.path("src"));
    unit_tests.addCSourceFile(.{
        .file = b.path("src/stb_implementation.c"),
        .flags = &.{
            "-std=c99",
            "-fno-sanitize=undefined",
            "-g",
            "-O0",
        },
    });
    unit_tests.linkLibC();
    unit_tests.linkSystemLibrary("glew");
    unit_tests.linkSystemLibrary("glfw");

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
