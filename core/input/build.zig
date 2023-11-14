const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/input/";

const sources = &.{
    here ++ "input.cpp",
    here ++ "input_event.cpp",
    here ++ "input_map.cpp",
    here ++ "shortcut.cpp",
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
