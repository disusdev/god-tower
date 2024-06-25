const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{.preferred_optimize_mode = .ReleaseSafe});

    const tracy_enable = false;// b.option(bool, "tracy_enable", "Enable profiling") orelse true;

    const tracy = b.dependency("tracy", .{
        .target = target,
        .optimize = optimize,
        .tracy_enable = tracy_enable,
    });

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = .ReleaseFast,
    });
    const raylib = raylib_dep.artifact("raylib");
    
    b.installDirectory(.{
        .source_dir = b.path("external"),
        .install_dir = .lib,
        .install_subdir = "external",
    });

    b.installDirectory(.{
        .source_dir = b.path("src"),
        .install_dir = .bin,
        .install_subdir = "src",
    });

    const exe = b.addExecutable(.{
        .name = "got-tower",
        .root_source_file = b.path("src/game.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("tracy", tracy.module("tracy"));
    exe.linkLibrary(tracy.artifact("tracy"));
    exe.linkLibC();
    exe.linkLibCpp();

    exe.addIncludePath(raylib_dep.path(""));
    exe.linkLibrary(raylib);

    exe.addIncludePath(b.path("src"));
    exe.addIncludePath(b.path("raylib/src"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // const lib_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    //const test_step = b.step("test", "Run unit tests");
    //test_step.dependOn(&run_lib_unit_tests.step);
}
