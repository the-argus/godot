const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "platform/windows/";

const common_win = &.{
    here ++ "godot_windows.cpp",
    here ++ "crash_handler_windows.cpp",
    here ++ "os_windows.cpp",
    here ++ "display_server_windows.cpp",
    here ++ "key_mapping_windows.cpp",
    here ++ "joypad_windows.cpp",
    here ++ "tts_windows.cpp",
    here ++ "windows_terminal_logger.cpp",
    here ++ "vulkan_context_win.cpp",
    here ++ "gl_manager_windows.cpp",
};

const common_win_wrap = &.{
    here ++ "console_wrapper_windows.cpp",
};

const STACK_SIZE = "8388608";

/// Takes the configuration and modifies engine target and adds some C sources.
/// Also adds some flags.
pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    if (config.platform != .windows) @panic("Attempted to build for windows but no configuration provided.");

    // figure out what flags we need for this platform
    var flags = try std.ArrayList([]const u8).init(b.allocator);
    var linkflags = try std.ArrayList([]const u8).init(b.allocator);
    defer linkflags.deinit();
    defer flags.deinit();

    if (config.engine_target == .template_release) {
        try flags.append("-msse2");
    } else if (config.dev_build) {
        try flags.appendSlice(&.{ "-Wa", "-mbig-obj" });
    }

    switch (config.platform_windows.?.subsystem) {
        .Gui => {
            try linkflags.appendSlice(&.{ "--subsystem", "windows" });
        },
        .Console => {
            try linkflags.appendSlice(&.{ "--subsystem", "console" });
            try flags.append("-DWINDOWS_SUBSYSTEM_CONSOLE");
        },
    }

    try linkflags.appendSlice(&.{ "--stack", STACK_SIZE });

    const winver_flag = std.fmt.allocPrint(b.allocator, "-DWINVER={any}", .{});
    const winnt_flag = std.fmt.allocPrint(b.allocator, "_WIN32_WINNT={any}", .{});
    std.log.debug("winver flag: {s}", .{winver_flag});
    std.log.debug("winnt flag: {s}", .{winnt_flag});

    try flags.appendSlice(&.{
        "-mwindows",
        "-DWINDOWS_ENABLED",
        "-DWASAPI_ENABLED",
        "-DWINMIDI_ENABLED",
        winver_flag,
        winnt_flag,
    });

    // flags done, now do libs
    const libs = try std.ArrayList([]const u8).init(b.allocator);
    defer libs.deinit();

    {
        const initial_libs = &.{
            // "mingw32",
            "dsound",
            "ole32",
            "d3d9",
            "winmm",
            "gdi32",
            "iphlpapi",
            "shlwapi",
            "wsock32",
            "ws2_32",
            "kernel32",
            "oleaut32",
            "sapi",
            "dinput8",
            "dxguid",
            "ksuser",
            "imm32",
            "bcrypt",
            "crypt32",
            "avrt",
            "uuid",
            "dwmapi",
            "dwrite",
            "wbemuuid",
        };

        try libs.appendSlice(initial_libs);

        if (config.debugging_features) {
            try libs.appendSlice(&.{ "psapi", "dbghelp" });
        }

        if (config.vulkan) {
            try flags.append("-DVULKAN_ENABLED");
            if (!config.use_volk) {
                try libs.append("vulkan");
            }
        }

        if (config.opengl3) {
            try flags.append("-DGLES3_ENABLED");
            try libs.append("opengl32");
        }
    }

    // combine all flags and libs and add the source files and the flags to the
    // state
    const ourflags = interface.combineFlags(b.allocator, flags.items, linkflags.items);
    try state.flags.appendSlice(ourflags);

    state.executable.addCSourceFiles(common_win, std.mem.join(b.allocator, &.{}, &.{ ourflags, config.universal_flags }));

    for (libs.items) |lib| {
        state.executable.linkSystemLibrary(lib);
    }

    std.log.warn("Windows console app wrapper not implemented, and building without a .res file", .{});
}
