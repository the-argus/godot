const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/os/";

const sources = &.{
    here ++ "keyboard.cpp",
    here ++ "main_loop.cpp",
    here ++ "memory.cpp",
    here ++ "midi_driver.cpp",
    here ++ "mutex.cpp",
    here ++ "os.cpp",
    here ++ "pool_allocator.cpp",
    here ++ "thread.cpp",
    here ++ "thread_safe.cpp",
    here ++ "time.cpp",
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
