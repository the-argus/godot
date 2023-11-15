const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/templates/";

const sources = &.{
    here ++ "command_queue_mt.cpp",
    here ++ "rid_owner.cpp",
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
