const std = @import("std");
const interface = @import("../build_interface.zig");

const here = "main/";

const sources = &.{
    here ++ "main.cpp",
    here ++ "main_timer_sync.cpp",
    here ++ "performance.cpp",
};

pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    _ = b;

    var flags = std.ArrayList([]const u8).init();
    defer flags.deinit();

    if (config.tests) try flags.append("-DTESTS_ENABLED");

    state.executable.addCSourceFiles(sources, &.{});
}

fn makeSplashContents(ally: std.mem.Allocator, splash_path: []const u8) ![]u8 {
    _ = splash_path;
    _ = ally;
	
}

// def make_splash(target, source, env):
//     src = source[0]
//     dst = target[0]

//     with open(src, "rb") as f:
//         buf = f.read()

//     with open(dst, "w") as g:
//         g.write("/* THIS FILE IS GENERATED DO NOT EDIT */\n")
//         g.write("#ifndef BOOT_SPLASH_H\n")
//         g.write("#define BOOT_SPLASH_H\n")
//         # Use a neutral gray color to better fit various kinds of projects.
//         g.write("static const Color boot_splash_bg_color = Color(0.14, 0.14, 0.14);\n")
//         g.write("static const unsigned char boot_splash_png[] = {\n")
//         for i in range(len(buf)):
//             g.write(str(buf[i]) + ",\n")
//         g.write("};\n")
//         g.write("#endif")
