const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/extension/";

const sources = &.{
    here ++ "extension_api_dump.cpp",
    here ++ "gdextension.cpp",
    here ++ "gdextension_interface.cpp",
    here ++ "gdextension_manager.cpp",
};

// TODO: add make_wrappers and make_interface_dumpers
pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    _ = config;
    _ = b;
    state.executable.addCSourceFiles(sources, &.{});
}
