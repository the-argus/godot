const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/debugger/";

const sources = &.{
    here ++ "debugger_marshalls.cpp",
    here ++ "engine_debugger.cpp",
    here ++ "engine_profiler.cpp",
    here ++ "local_debugger.cpp",
    here ++ "remote_debugger.cpp",
    here ++ "remote_debugger_peer.cpp",
    here ++ "script_debugger.cpp",
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
