const std = @import("std");
const interface = @import("../../build_interface.zig");

pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    _ = config;
    _ = b;
    state.executable.addCSourceFiles(&.{
        "engine.cpp",
        "project_settings.cpp",
    }, &.{});
}
