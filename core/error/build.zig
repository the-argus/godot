const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/error/";

const sources = &.{
    here ++ "error_list.cpp",
    here ++ "error_macros.cpp",
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
