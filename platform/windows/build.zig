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

pub fn configure(
    b: *std.Build,
    config: *interface.EngineBuildConfiguration,
) void {
    if (config.platform_windows == null) @panic("Attempted to build for windows but no configuration provided.");

    var flags = std.ArrayList([]const u8).init(b.allocator);
    var linkflags = std.ArrayList([]const u8).init(b.allocator);
    defer linkflags.deinit();
    defer flags.deinit();

    if (config.engine_target == .TemplateRelease) {
        flags.append("-msse2") catch @panic("OOM");
    } else if (config.dev_build) {
        flags.appendSlice(&.{ "-Wa", "-mbig-obj" }) catch @panic("OOM");
    }

    switch (config.platform_windows.?.subsystem) {
        .Gui => {
            linkflags.appendSlice(&.{ "--subsystem", "windows" }) catch @panic("OOM");
        },
        .Console => {
            linkflags.appendSlice(&.{ "--subsystem", "console" }) catch @panic("OOM");
            flags.append("-DWINDOWS_SUBSYSTEM_CONSOLE") catch @panic("OOM");
        },
    }

    linkflags.appendSlice(&.{ "--stack", STACK_SIZE }) catch @panic("OOM");

    const winver_flag = std.fmt.allocPrint(b.allocator, "-DWINVER={any}", .{});
    const winnt_flag = std.fmt.allocPrint(b.allocator, "_WIN32_WINNT={any}", .{});
    std.log.debug("winver flag: {s}", .{winver_flag});
    std.log.debug("winnt flag: {s}", .{winnt_flag});

    flags.appendSlice(&.{
        "-mwindows",
        "-DWINDOWS_ENABLED",
        "-DWASAPI_ENABLED",
        "-DWINMIDI_ENABLED",
        winver_flag,
        winnt_flag,
    }) catch @panic("OOM");

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
    const libs = std.ArrayList([]const u8).init(b.allocator) catch @panic("OOM");
    defer libs.deinit();

    libs.appendSlice(initial_libs) catch @panic("OOM");

    if (config.debugging_features) {
        libs.appendSlice(&.{ "psapi", "dbghelp" }) catch @panic("OOM");
    }

    if (config.vulkan) {
        flags.append("-DVULKAN_ENABLED") catch @panic("OOM");
        if (!config.use_volk) {
            libs.append("vulkan") catch @panic("OOM");
        }
    }

    if (config.opengl3) {
        flags.append("-DGLES3_ENABLED") catch @panic("OOM");
        libs.append("opengl32") catch @panic("OOM");
    }

    var windows = b.addExecutable(.{
        .optimize = config.getZigOptimizeMode(),
        .target = config.platform_windows.?.target,
        .app_name = "godot",
    });

    defer flags.deinit();
    defer linkflags.deinit();
    const allflags = interface.combineFlags(b.allocator, config.universal_flags, flags.items, linkflags.items);

    windows.addCSourceFiles(common_win, allflags);

    defer libs.deinit();
    for (libs.items) |lib| {
        windows.linkSystemLibrary(lib);
    }

    std.log.warn("Windows console app wrapper not implemented, and building without a .res file", .{});
}
