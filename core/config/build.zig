const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/config/";

const sources = &.{
    here ++ "engine.cpp",
    here ++ "project_settings.cpp",
};

pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    _ = config;
    _ = b;
    state.executable.addCSourceFiles(sources, &.{});
}
