const std = @import("std");
const interface = @import("../../build_interface.zig");

const here = "core/math/";

const sources = &.{
    here ++ "aabb.cpp",
    here ++ "a_star.cpp",
    here ++ "a_star_grid_2d.cpp",
    here ++ "audio_frame.cpp",
    here ++ "basis.cpp",
    here ++ "color.cpp",
    here ++ "convex_hull.cpp",
    here ++ "face3.cpp",
    here ++ "geometry_2d.cpp",
    here ++ "geometry_3d.cpp",
    here ++ "math_fieldwise.cpp",
    here ++ "math_funcs.cpp",
    here ++ "plane.cpp",
    here ++ "projection.cpp",
    here ++ "quaternion.cpp",
    here ++ "quick_hull.cpp",
    here ++ "random_number_generator.cpp",
    here ++ "random_pcg.cpp",
    here ++ "rect2.cpp",
    here ++ "rect2i.cpp",
    here ++ "static_raycaster.cpp",
    here ++ "transform_2d.cpp",
    here ++ "transform_3d.cpp",
    here ++ "triangle_mesh.cpp",
    here ++ "triangulate.cpp",
    here ++ "vector2.cpp",
    here ++ "vector2i.cpp",
    here ++ "vector3.cpp",
    here ++ "vector3i.cpp",
    here ++ "vector4.cpp",
    here ++ "vector4i.cpp",
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
