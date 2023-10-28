const std = @import("std");
const interface = @import("../../../build_interface.zig");

const here = "platform/linuxbsd/x11/";

const source_files = &.{
    here ++ "display_server_x11.cpp",
    here ++ "key_mapping_x11.cpp",
};

const sowrap_sources = &.{
    here ++ "dynwrappers/xlib-so_wrap.c",
    here ++ "dynwrappers/xcursor-so_wrap.c",
    here ++ "dynwrappers/xinerama-so_wrap.c",
    here ++ "dynwrappers/xinput2-so_wrap.c",
    here ++ "dynwrappers/xrandr-so_wrap.c",
    here ++ "dynwrappers/xrender-so_wrap.c",
    here ++ "dynwrappers/xext-so_wrap.c",
};

pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    const sources = std.ArrayList([]const u8).init(b.allocator);
    defer sources.deinit();
    try sources.appendSlice(source_files);

    if (config.use_sowrap) {
        try sources.appendSlice(sowrap_sources);
    }

    if (config.vulkan) {
        try sources.append(here ++ "vulkan_context_x11.cpp");
    }

    if (config.opengl3) {
        // public define for use in other places
        try state.flags.append("-DGLAD_GLX_NO_X11");
        try sources.appendSlice(&.{
            here ++ "gl_manager_x11.cpp",
            here ++ "detect_prime_x11.cpp",
            "thirdparty/glad/glx.c",
        });
    }
}
