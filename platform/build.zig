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
) []std.Build.LazyPath {
    var sources = std.ArrayList(std.Build.LazyPath).init(b.allocator) catch @panic("OOM");

    const platform_apis_source_writefile_step = b.addWriteFile(
        "register_platform_apis.gen.cpp",
        generatePlatformApisSource(b, config),
    );
    sources.append(platform_apis_source_writefile_step.files.items[0].generated_file.getPath());

    if (config.platform_windows) |_| {
        const win = @import("windows/build.zig");
        _ = win;
    }

    return sources.toOwnedSlice();
}

fn generatePlatformApisSource(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
) []const u8 {
    var source = std.ArrayList(u8).init(b.allocator) catch @panic("OOM");

    var platform_names = std.ArrayList([]const u8).init(b.allocator) catch @panic("OOM");
    defer platform_names.deinit();

    // find all struct fields prefixed with platform_ in the EngineBuildConfiguration.
    // add the stuff afterwards (for example "windows" in platform_windows) to the list
    // of platform names
    const platform_prefix = "platform_";
    for (@typeInfo(interface.EngineBuildConfiguration).Struct.fields) |field| {
        // make sure the field is optional
        if (@typeInfo(field.type) != .Optional) continue;
        // make sure the field name is long enough to even contain the prefix
        if (field.name.len < platform_prefix.len) continue;
        // if the optional contains nothing, its probably a platform thats not enabled
        @field(config, field.name) orelse continue;
        if (std.mem.eql(u8, field.name[0..platform_prefix.len], platform_prefix)) {
            const platform_name = field.name[platform_prefix.len..];
            if (platform_name.len <= 0) {
                std.log.err("Invalid platform name {s}", .{field.name});
                @panic("Invalid empty platform name.");
            }
            platform_names.append(platform_name) catch @panic("OOM");
        }
    }

    if (platform_names.len == 0) @panic("No platforms enabled.");

    source.appendSlice("#include \"platforms/register_platform_apis.h\"\n") catch @panic("OOM");

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
            source.appendSlice(line) catch @panic("OOM");
        }
    }

    return source.toOwnedSlice();
}
