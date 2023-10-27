const std = @import("std");
const zcc = @import("compile_commands");
const interface = @import("build_interface.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const dev_build = b.option(
        bool,
        "dev_build",
        "Enable a build with settings meant for engine developers.",
    ) orelse false;

    const debugging_symbols = b.option(
        bool,
        "debugging_symbols",
        "Build with debugging symbols in the executable.",
    ) orelse false;

    const engine_optimize_opt: ?interface.EngineBuildConfiguration.EngineOptimizeMode = b.option(
        interface.EngineBuildConfiguration.EngineOptimizeMode,
        "engine_optimize",
        "Optimization mode which can be more specific than the Debug/ReleaseSmall/ReleaseFast offered by Zig.",
    );

    const engine_optimize = interface.resolveEngineOptimizeMode(mode, engine_optimize_opt) catch |err| {
        std.log.err(
            "Failed to resolve differences between the zig optimize mode {any} and the engine_optimize mode {any}:",
            .{ mode, engine_optimize_opt },
        );
        @panic(err);
    };

    const werror = b.option(
        bool,
        "werror",
        "Enable the \"warnings as errors\" option in the compiler.",
    ) orelse engine_optimize == .Debug;

    const disable_exceptions = b.option(
        bool,
        "disable_exceptions",
        "Whether to disable C++ exceptions. Defaults to false.",
    ) orelse false;

    const warning_mode = b.option(
        interface.EngineBuildConfiguration.EngineWarningMode,
        "warning_mode",
        "The amount of warnings the compiled engine should print when it's run.",
    ) orelse interface.EngineBuildConfiguration.EngineWarningMode.All;

    // TODO: production build option, which just sets other options
    // TODO:  these:
    // custom_modules: ?[]u8,
    // custom_modules_recursive: bool
    // TODO: build_profile

    const dynflags = std.ArrayList([]const u8).init(b.allocator);

    if (debugging_symbols) {
        dynflags.append("-gdwarf-4") catch @panic("OOM");
        dynflags.append(if (dev_build) "-g3" else "-g2") catch @panic("OOM");
    } else {
        dynflags.append("-Wl,-s") catch @panic("OOM");
    }

    dynflags.append(switch (engine_optimize) {
        .Speed => "-O3",
        .SpeedTrace => "-O2",
        .Size => "-Os",
        .Debug => "-Og",
        .None => "-O0",
    }) catch @panic("OOM");

    dynflags.append("-std=c++17") catch @panic("OOM");

    if (disable_exceptions) dynflags.append("-fno-exceptions") catch @panic("OOM");

    // universal warnings
    dynflags.appendSlice(&.{
        "-Wshadow-field-in-constructor",
        "-Wshadow-uncaptured-local",
        // We often implement `operator<` for structs of pointers as a requirement
        // for putting them in `Set` or `Map`. We don't mind about unreliable ordering.
        "-Wno-ordered-compare-function-pointers",
    }) catch @panic("OOM");

    // warnings depending on settings
    dynflags.appendSlice(switch (warning_mode) {
        .Extra => &.{
            "-Wall",
            "-Wextra",
            "-Wwrite-strings",
            "-Wno-unused-parameter",
            "-Wctor-dtor-privacy",
            "-Wnon-virtual-dtor",
            "-Wimplicit-fallthrough",
        },
        .All => &.{
            "-Wall",
        },
        .Moderate => &.{
            "-Wall",
            "-Wno-unused",
        },
        .No => &.{
            "-w",
        },
    }) catch @panic("OOM");

    if (werror) dynflags.append("-Werror") catch @panic("OOM");

    const config = interface.EngineBuildConfiguration{
        .target = target,
        .universal_flags = dynflags.toOwnedSlice(),
        .disable_exceptions = disable_exceptions,
        .warning_mode = warning_mode,
        .engine_optimize = engine_optimize,
        .dev_build = dev_build,
    };

    const targets = interface.engineBuild(b, config) catch |err| {
        @panic(err);
    };

    zcc.createStep(b, "cdb", targets);
}
