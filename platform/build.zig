const std = @import("std");
const interface = @import("../build_interface.zig");

/// Main entrypoint into the platforms. Modifies the state based on the given
/// configuration, adding the necessary source files and flags.
pub fn configure(
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineConfigureState,
) void {
    _ = state;
    _ = config;
}

fn getSourceFiles(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
) ![]std.Build.LazyPath {
    var sources = try std.ArrayList(std.Build.LazyPath).init(b.allocator);

    const platform_apis_source_writefile_step = b.addWriteFile(
        "register_platform_apis.gen.cpp",
        generatePlatformApisSource(b),
    );
    sources.append(platform_apis_source_writefile_step.files.items[0].generated_file.getPath());

    if (config.platform_windows) |_| {
        const win = @import("windows/build.zig");
        _ = win;
    }

    return try sources.toOwnedSlice();
}

fn generatePlatformApisSource(
    b: *std.Build,
) ![]const u8 {
    var source = try std.ArrayList(u8).init(b.allocator);

    var platform_names = try std.ArrayList([]const u8).init(b.allocator);
    defer platform_names.deinit();

    for (@typeInfo(interface.EngineBuildConfiguration.EnginePlatformSpecificOptions).Union.fields) |field| {
        try platform_names.append(field.name);
    }

    if (platform_names.len == 0) @panic("No platforms?");

    try source.appendSlice("#include \"platforms/register_platform_apis.h\"\n");

    // add a block of lines for each of these formats. so there will be a block of
    // #include platforms/.../api.h, and then a block of register_..._api(); and
    // then another for unregister.
    const format_strings = &.{
        "\t#include \"platforms/{s}/api/api.h\"\n",
        "\tregister_{s}_api();\n",
        "\tunregister_{s}_api();\n",
    };

    for (format_strings) |format| {
        for (platform_names.items) |platform_name| {
            var line = std.fmt.allocPrint(b.allocator, format, .{platform_name});
            defer b.allocator.free(line);
            try source.appendSlice(line);
        }
    }

    return source.toOwnedSlice();
}
