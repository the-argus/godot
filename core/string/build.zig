const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/string/";

const sources = &.{
    here ++ "node_path.cpp",
    here ++ "optimized_translation.cpp",
    here ++ "print_string.cpp",
    here ++ "string_builder.cpp",
    here ++ "string_name.cpp",
    here ++ "translation.cpp",
    here ++ "ustring.cpp",
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
