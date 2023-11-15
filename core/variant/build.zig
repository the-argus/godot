const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/variant/";

const sources = &.{
    here ++ "array.cpp",
    here ++ "callable.cpp",
    here ++ "callable_bind.cpp",
    here ++ "dictionary.cpp",
    here ++ "variant.cpp",
    here ++ "variant_call.cpp",
    here ++ "variant_construct.cpp",
    here ++ "variant_destruct.cpp",
    here ++ "variant_internal.cpp",
    here ++ "variant_op.cpp",
    here ++ "variant_parser.cpp",
    here ++ "variant_setget.cpp",
    here ++ "variant_utility.cpp",
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
