const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "platform/linuxbsd/";

const common_linuxbsd = &.{
    here ++ "godot_linuxbsd.cpp",
    here ++ "crash_handler_linuxbsd.cpp",
    here ++ "os_linuxbsd.cpp",
    here ++ "joypad_linux.cpp",
    here ++ "freedesktop_portal_desktop.cpp",
    here ++ "freedesktop_screensaver.cpp",
};

pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    const sources = std.ArrayList([]const u8).init(b.allocator);

    // gather sources
    {
        try sources.appendSlice(common_linuxbsd);

        if (config.use_sowrap) {
            try sources.append("xkbcommon-so_wrap.c");
        }

        if (config.x11) {
            @import("x11/build.zig").configure(b, config, state);
        }

        if (config.speechd) {
            try sources.append("tts_linux.cpp");
            if (config.use_sowrap) {
                try sources.append("speechd-so_wrap.c");
            }
        }

        if (config.fontconfig and config.use_sowrap) {
            try sources.append("fontconfig-so_wrap.c");
        }

        if (config.udev and config.use_sowrap) {
            try sources.append("libudev-so_wrap.c");
        }

        if (config.dbus and config.use_sowrap) {
            try sources.append("dbus-so_wrap.c");
        }

        if (config.debug_symbols and config.separate_debug_symbols) {
            // os.system("objcopy --only-keep-debug {0} {0}.debugsymbols".format(target[0]))
            // os.system("strip --strip-debug --strip-unneeded {0}".format(target[0]))
            // os.system("objcopy --add-gnu-debuglink={0}.debugsymbols {0}".format(target[0]))
            if (b.host.target.os.tag != .linux) {
                std.log.warn("Attempting to build linux target with separate debug symbols " ++
                    "on a non-linux host. objcopy and strip may not be present.", &.{});
            }

            const debug_symbols_name = std.fmt.allocPrint(b.allocator, "{s}.debugsymbols", .{state.executable.name});
            defer b.allocator.free(debug_symbols_name);

            const debug_symbols_file = b.cache_root.join(b.allocator, &.{debug_symbols_name});

            const objcopy_create_debug_symbols = b.addSystemCommand(&.{ "objcopy", "--only-keep-debug" });
            objcopy_create_debug_symbols.addArtifactArg(state.executable);
            objcopy_create_debug_symbols.addArg(debug_symbols_name);

            const strip = b.addSystemCommand(&.{ "strip", "--strip-debug", "--strip-unneeded" });
            strip.addArtifactArg(state.executable);

            const objcopy_link_to_stripped_executable = b.addSystemCommand(&.{
                "objcopy",
                std.fmt.allocPrint(b.allocator, "--add-gnu-debuglink={s}", .{debug_symbols_file}),
            });
            objcopy_link_to_stripped_executable.addArtifactArg(state.executable);

            // declare dependency chain
            b.getInstallStep().dependOn(objcopy_link_to_stripped_executable);
            objcopy_link_to_stripped_executable.step.dependOn(strip.step);
            strip.step.dependOn(objcopy_create_debug_symbols.step);
            objcopy_create_debug_symbols.step.dependOn(state.executable);
        }
    }
}
