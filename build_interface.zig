const std = @import("std");

pub const EngineBuildConfiguration = struct {
    engine_target: EngineTarget,
    optimize: EngineOptimizeMode,
    lto: EngineLTOMode,
    debugging_symbols: bool,
    separate_debug_symbols: bool,
    deprecated: bool,
    precision: EngineFloatingPrecision,

    // components
    minizip: bool,
    brotli: bool,
    xaudio2: bool,
    vulkan: bool,
    opengl3: bool,
    openxr: bool,
    use_volk: bool,
    custom_modules: []const []const u8,
    disable_exceptions: bool,

    // advanced options
    dev_build: bool,
    tests: bool,
    fast_unsafe: bool,
    verbose: bool,
    progress: bool,
    warnings: EngineWarningMode,
    werror: bool,
    extra_suffix: ?[]const u8,
    disable_3d: bool,
    disable_advanced_gui: bool,
    modules_enabled_by_default: bool, // consider resolving this to some []Modules before passing to engineBuild
    no_editor_splash: bool,
    system_certs_path: ?[]const u8,
    use_precise_math_checks: bool,
    scu_build: bool,

    // thirdparty libs
    builtin_brotli: bool,
    builtin_certs: bool,
    builtin_embree: bool,
    builtin_enet: bool,
    builtin_freetype: bool,
    builtin_msdfgen: bool,
    builtin_glslang: bool,
    builtin_graphite: bool,
    builtin_harfbuzz: bool,
    builtin_icu4c: bool,
    builtin_libogg: bool,
    builtin_libpng: bool,
    builtin_libtheora: bool,
    builtin_libvorbis: bool,
    builtin_libwebp: bool,
    builtin_wslay: bool,
    builtin_mbedtls: bool,
    builtin_miniupnpc: bool,
    builtin_openxr: bool,
    builtin_pcre2: bool,
    builtin_pcre2_with_jit: bool,
    builtin_recastnavigation: bool,
    builtin_rvo2_2d: bool,
    builtin_rvo2_3d: bool,
    builtin_squish: bool,
    builtin_xatlas: bool,
    builtin_zlib: bool,
    builtin_zstd: bool,

    // platform options
    platform_opts: PlatformOptions,

    pub const PlatformOptions = union(enum) {
        windows: EngineBuildConfigurationWindows,
        web: EngineBuildConfigurationWeb,
        uwp: EngineBuildConfigurationUWP,
        macos: EngineBuildConfigurationMacOS,
        linuxbsd: EngineBuildConfigurationLinuxBSD,
        ios: EngineBuildConfigurationIOS,
        android: EngineBuildConfigurationAndroid,

        pub const EngineBuildConfigurationWindows = struct {
            use_asan: bool,
        };

        pub const EngineBuildConfigurationWeb = struct {
            initial_memory: u64, // 32 by default
            use_assertions: bool,
            use_ubsan: bool,
            use_lsan: bool,
            use_safe_heap: bool,
            javascript_eval: bool,
            dlink_enabled: bool,
            use_closure_compiler: bool,
        };

        pub const EngineBuildConfigurationUWP = struct {};

        pub const EngineBuildConfigurationMacOS = struct {
            osxcross_sdk: []const u8, // default "darwin16"
            macos_sdk_path: ?[]const u8,
            vulkan_sdk_path: ?[]const u8,
            use_ubsan: bool,
            use_asan: bool,
            use_tsan: bool,
            use_coverage: bool,
        };

        pub const EngineBuildConfigurationLinuxBSD = struct {
            use_coverage: bool,
            use_ubsan: bool,
            use_asan: bool,
            use_lsan: bool,
            use_tsan: bool,
            use_msan: bool,
            use_sowrap: bool,
            alsa: bool,
            pulseaudio: bool,
            dbus: bool,
            speechd: bool,
            fontconfig: bool,
            udev: bool,
            x11: bool,
            touch: bool,
        };

        pub const EngineBuildConfigurationIOS = struct {
            ios_toolchain_path: []const u8, // default is "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"
            ios_sdk_path: ?[]const u8,
            ios_triple: ?[]const u8,
            ios_simulator: bool,
        };

        pub const EngineBuildConfigurationAndroid = struct {
            android_sdk_root: []const u8,
            ndk_platform: []const u8,
            store_release: bool,
        };
    };

    pub const EngineOptimizeMode = enum {
        Speed,
        SpeedTrace,
        Size,
        Custom,
        Debug,
        None,
    };

    pub const EngineWarningMode = enum {
        No,
        Moderate,
        All,
        Extra,
    };

    pub const EngineTarget = enum {
        Editor,
        TemplateRelease,
        TemplateDebug,
    };

    pub const EngineLTOMode = enum {
        None,
        Auto,
        Thin,
        Full,
    };

    pub const EngineFloatingPrecision = enum { Single, Double };
};

pub fn engineBuild(b: *std.Build, config: EngineBuildConfiguration) !void {
    _ = config;
    _ = b;
}

pub const EngineBuildOptionError = error{ConflictingEngineAndActualBuildModes};

pub fn resolveEngineOptimizeMode(
    actual_mode: std.builtin.mode,
    engine_mode: ?EngineBuildConfiguration.EngineOptimizeMode,
) !EngineBuildConfiguration.EngineOptimizeMode {
    if (engine_mode) |mode| {
        // ensure we're not conflicting
        switch (actual_mode) {
            .ReleaseFast => {
                if (mode != .Speed and mode != .SpeedTrace) {
                    return EngineBuildOptionError.ConflictingEngineAndActualBuildModes;
                }
            },
            .ReleaseSmall => {
                if (mode != .Size) {
                    return EngineBuildOptionError.ConflictingEngineAndActualBuildModes;
                }
            },
            .Debug => {
                if (mode != .None and mode != .Debug) {
                    return EngineBuildOptionError.ConflictingEngineAndActualBuildModes;
                }
            },
        }

        return mode;
    } else {
        // no engine mode specified, get the default one given the regular build mode
        return switch (actual_mode) {
            .Debug => .Debug,
            .ReleaseSmall => .Size,
            .ReleaseFast => .Speed,
        };
    }
}
