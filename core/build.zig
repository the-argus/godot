const std = @import("std");

const interface = @import("../build_interface.zig");

pub fn configure(
    b: *std.Build,
    config: interface.EngineBuildConfiguration,
    state: *interface.EngineBuildConfiguration.State,
) !void {
    const sources = std.ArrayList([]const u8).init(b.allocator);
    const flags = std.ArrayList([]const u8).init(b.allocator);
    defer sources.deinit();
    defer flags.deinit();

    const key_source_filepath = b.cache_root.join(b.allocator, &.{"script_encryption_key.gen.cpp"});
    const gen_key_source = b.addWriteFile(key_source_filepath, try genKeySourceFileContents(b.allocator));
    state.executable.step.dependOn(gen_key_source.step);
    try sources.append(key_source_filepath);

    // grab miscellaneous third party single-source-file dependencies
    {
        const thirdparty_misc = "thirdparty/misc/";
        try sources.appendSlice(&.{
            // C sources
            thirdparty_misc ++ "fastlz.c",
            thirdparty_misc ++ "r128.c",
            thirdparty_misc ++ "smaz.c",
            // C++ sources
            thirdparty_misc ++ "pcg.cpp",
            thirdparty_misc ++ "polypartition.cpp",
            thirdparty_misc ++ "clipper.cpp",
            thirdparty_misc ++ "smolv.cpp",
        });
    }

    // brotli
    if (config.brotli and config.builtin_brotli) {
        const brotli_dir = "thirdparty/brotli/";

        try sources.appendSlice(&.{
            brotli_dir ++ "common/constants.c",
            brotli_dir ++ "common/context.c",
            brotli_dir ++ "common/dictionary.c",
            brotli_dir ++ "common/platform.c",
            brotli_dir ++ "common/shared_dictionary.c",
            brotli_dir ++ "common/transform.c",
            brotli_dir ++ "dec/bit_reader.c",
            brotli_dir ++ "dec/decode.c",
            brotli_dir ++ "dec/huffman.c",
            brotli_dir ++ "dec/state.c",
        });

        // add public flags/includes to all source files
        try state.flags.append(std.fmt.allocPrint(b.allocator, "-I{s}", .{brotli_dir ++ "include"}));
        if (config.useUbsan() or config.useAsan() or config.useTsan() or config.useLsan() or config.useMsan()) {
            try state.flags.append("-DBROTLI_BUILD_PORTABLE");
        }
    }

    // zlib
    if (config.builtin_zlib) {
        const zlib_dir = "thirdparty/zlib/";
        try sources.appendSlice(&.{
            zlib_dir ++ "adler32.c",
            zlib_dir ++ "compress.c",
            zlib_dir ++ "crc32.c",
            zlib_dir ++ "deflate.c",
            zlib_dir ++ "inffast.c",
            zlib_dir ++ "inflate.c",
            zlib_dir ++ "inftrees.c",
            zlib_dir ++ "trees.c",
            zlib_dir ++ "uncompr.c",
            zlib_dir ++ "zutil.c",
        });

        if (config.dev_build) try state.flags.append("-DZLIB_DEBUG");

        // publically allow including from zlib headers
        state.flags.append(std.fmt.allocPrint(b.allocator, "-I{s}", .{zlib_dir}));
    }

    // minizip
    {
        const minizip_dir = "thirdparty/minizip/";
        try sources.appendSlice(&.{
            minizip_dir ++ "ioapi.c",
            minizip_dir ++ "unzip.c",
            minizip_dir ++ "zip.c",
        });
    }

    if (config.builtin_zstd) {
        const zstd_dir = "thirdparty/zstd/";
        try sources.appendSlice(&.{
            zstd_dir ++ "common/debug.c",
            zstd_dir ++ "common/entropy_common.c",
            zstd_dir ++ "common/error_private.c",
            zstd_dir ++ "common/fse_decompress.c",
            zstd_dir ++ "common/pool.c",
            zstd_dir ++ "common/threading.c",
            zstd_dir ++ "common/xxhash.c",
            zstd_dir ++ "common/zstd_common.c",
            zstd_dir ++ "compress/fse_compress.c",
            zstd_dir ++ "compress/hist.c",
            zstd_dir ++ "compress/huf_compress.c",
            zstd_dir ++ "compress/zstd_compress.c",
            zstd_dir ++ "compress/zstd_double_fast.c",
            zstd_dir ++ "compress/zstd_fast.c",
            zstd_dir ++ "compress/zstd_lazy.c",
            zstd_dir ++ "compress/zstd_ldm.c",
            zstd_dir ++ "compress/zstd_opt.c",
            zstd_dir ++ "compress/zstdmt_compress.c",
            zstd_dir ++ "compress/zstd_compress_literals.c",
            zstd_dir ++ "compress/zstd_compress_sequences.c",
            zstd_dir ++ "compress/zstd_compress_superblock.c",
            zstd_dir ++ "decompress/huf_decompress.c",
            zstd_dir ++ "decompress/zstd_ddict.c",
            zstd_dir ++ "decompress/zstd_decompress_block.c",
            zstd_dir ++ "decompress/zstd_decompress.c",
        });

        switch (config.platform) {
            .android, .ios, .linuxbsd, .macos => {
                try sources.append(zstd_dir ++ "decompress/huf_decompress_amd64.S");
            },
            else => {},
        }

        // global flags
        try state.flags.appendSlice(&.{
            try std.fmt.allocPrint(b.allocator, "-I{s}", .{zstd_dir}),
            "-DZSTD_STATIC_LINKING_ONLY",
        });

        // flags only needed by the zstd sources
        try flags.append(try std.fmt.allocPrint(b.allocator, "-I{s}", .{zstd_dir ++ "common/"}));
    }
}

fn genKeySourceFileContents(ally: std.mem.Allocator) ![]const u8 {
    const default_key = "0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0";
    const environment = std.process.getEnvMap(ally);
    defer environment.deinit();
    const key_opt = environment.get("SCRIPT_AES256_ENCRYPTION_KEY");

    const key = block: {
        if (key_opt) |key| {
            if (key.len != 64) break :block null;

            const formattedkey = std.ArrayList(u8).init(ally);
            const floatlen: f32 = @floatFromInt(key.len);
            for (0..@intFromFloat(std.math.floor(floatlen / 2.0))) |i| {
                if (i > 0) try formattedkey.append(",");

                const txts = std.fmt.allocPrint(ally, "0x{s}", .{key[(i * 2)..((i * 2) + 2)]});
                defer ally.free(txts);

                // try to parse into i32. zig will see "0x" at the start and know its meant to be base 16
                std.fmt.parseInt(i32, txts, 0) catch |err| {
                    std.log.err("unable to parse encryption key from environment: {any}", .{err});
                    break :block null;
                };

                // its valid, go ahead and append it
                formattedkey.appendSlice(try txts.toOwnedSlice());
            }

            break :block try formattedkey.toOwnedSlice();
        } else {
            break :block default_key;
        }
    };

    if (key == null) {
        std.log.err("Error: Invalid AES256 encryption key, not 64 hexadecimal characters: '{s}'.\n" ++
            "Unset 'SCRIPT_AES256_ENCRYPTION_KEY' in your environment " ++
            "or make sure that it contains exactly 64 hexadecimal characters.", .{key});
        @panic("Invalid encryption key.");
    }

    return std.fmt.allocPrint(ally, "#include \"core/config/project_settings.h\"\nuint8_t script_encryption_key[32]={{s}};\n", &.{key});
}
