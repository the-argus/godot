const std = @import("std");
const zcc = @import("compile_commands");
const interface = @import("build_interface.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    _ = target;
    const mode = b.standardOptimizeOption(.{});

    const dev_build = b.option(
        bool,
        "dev_build",
        "Enable a build with settings meant for engine developers.",
    ) orelse false;

    const engine_optimize: ?interface.EngineOptimizeMode = b.option(
        interface.EngineOptimizeMode,
        "engine_optimize",
        "Optimization mode which can be more specific than the Debug/ReleaseSmall/ReleaseFast offered by Zig.",
    );

    const engine_lto = b.option(
        interface.EngineLTOMode,
        "engine_lto",
        "Link-time optimization mode. Defaults to Auto.",
    ) orelse interface.EngineLTOMode.Auto;

    const disable_exceptions = b.option(
        bool,
        "disable_exceptions",
        "Whether to disable C++ exceptions. Defaults to false.",
    ) orelse false;

    const warning_mode = b.option(
        interface.EngineWarningMode,
        "warning_mode",
        "The amount of warnings the compiled engine should print when it's run.",
    ) orelse interface.EngineWarningMode.All;

    // TODO: production build option, which just sets other options
    // TODO:  these:
    // custom_modules: ?[]u8,
    // custom_modules_recursive: bool
    // TODO: build_profile

    const config = interface.EngineBuildConfiguration{
        .disable_exceptions = disable_exceptions,
        .warning_mode = warning_mode,
        .engine_lto = engine_lto,
        .engine_optimize = try interface.resolveEngineOptimizeMode(mode, engine_optimize),
        .dev_build = dev_build,
    };
    try interface.engineBuild(b, config);

    var targets = std.ArrayList(*std.Build.CompileStep).init(b.allocator);
    zcc.createStep(b, "cdb", try targets.toOwnedSlice());
}
