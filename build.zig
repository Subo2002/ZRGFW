const std = @import("std");

pub const Options = struct {
    no_api: bool = false,
    osmesa: bool = false,
    egl: bool = false,
    buffer: bool = false,
    directx: bool = false,
    advanced_smooth_resize: bool = false,

    const default = Options{};

    pub fn getOptions(b: *std.Build) struct { Options, *std.Build.Step.Options } {
        const build_options = b.addOptions();
        const options: Options = .{
            .no_api = b.option(bool, "no_api", "Don't use any rendering API (no OpenGL, no Vulkan, no DirectX)") orelse default.no_api,
            .buffer = b.option(bool, "buffer", "Draw directly to (RGFW) window pixel buffer that is drawn to screen (the buffer is in the RGBA format)") orelse default.buffer,
            .osmesa = b.option(bool, "osmesa", "Use OSMesa as backend (instead of system's OpenGL API + regular OpenGL)") orelse default.osmesa,
            .egl = b.option(bool, "egl", "Use EGL for loading an OpenGL context (instead of the system's OpenGL API)") orelse default.egl,
            .directx = b.option(bool, "directx", "Use DirectX for the rendering backend (rather than OpenGL) (Windows only, defaults to OpenGL for Unix)") orelse default.directx,
            .advanced_smooth_resize = b.option(bool, "advanced_smooth_resize", "Use advanced methods for smooth resizing (may result in a spike in memory usage or worse performance) (eg. WM_TIMER and XSyncValue) (Linux only)") orelse default.advanced_smooth_resize,
        };
        build_options.addOption(bool, "no_api", options.no_api);
        build_options.addOption(bool, "opengl", !options.osmesa and !options.egl and !options.directx and !options.buffer and !options.no_api);
        build_options.addOption(bool, "osmesa", options.osmesa);
        build_options.addOption(bool, "egl", options.egl);
        build_options.addOption(bool, "buffer", options.buffer);
        build_options.addOption(bool, "directx", options.directx);
        build_options.addOption(bool, "advanced_smooth_resize", options.advanced_smooth_resize);
        return .{ options, build_options };
    }
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const o = Options.getOptions(b);
    //const options = o[0];

    const rgfw_module = b.addModule("RGFW", .{
        .root_source_file = b.path("src/rgfw.zig"),
        .target = target,
        .optimize = optimize,
    });

    rgfw_module.addCSourceFile(.{
        .file = b.path("RGFW.h"),
    });

    const rgfw_lib = b.addLibrary(.{
        .root_module = rgfw_module,
        .name = "rgfw",
        .linkage = .static,
    });

    rgfw_module.link_libc = true;
    switch (target.result.os.tag) {
        .linux => {
            //if (options.directx) {
            //    @panic("DirectX is not supported on linux systems");
            //}
            rgfw_module.linkSystemLibrary("X11", .{});
            rgfw_module.linkSystemLibrary("GL", .{});
            rgfw_module.linkSystemLibrary("Xrandr", .{});
            rgfw_module.addCMacro("RGFW_X11", "");
        },
        .windows => {
            const win32_dependency = b.dependency("zigwin32", .{});
            rgfw_module.addImport("win32", win32_dependency.module("win32"));

            rgfw_module.linkSystemLibrary("opengl32", .{});
            rgfw_module.linkSystemLibrary("gdi32", .{});
            rgfw_module.addCMacro("RGFW_WINDOWS", "");
        },
        .macos => {
            // Should work on a Mac but I can't test it ¯\_(ツ)_/¯
            rgfw_module.linkFramework("Cocoa", .{ .needed = true });
            rgfw_module.linkFramework("OpenGL", .{ .needed = true });
            rgfw_module.linkFramework("IOKit", .{ .needed = true });
            rgfw_lib.root_module.addCMacro("RGFW_MACOS", "");
        },
        else => {},
    }

    rgfw_lib.root_module.addCMacro("RGFW_bool", "u8");
    //if (options.buffer) {
    //    rgfw_lib.root_module.addCMacro("RGFW_BUFFER", "");
    //}
    //if (options.osmesa) {
    //    rgfw_lib.root_module.addCMacro("RGFW_OSMESA", "");
    //}
    //if (options.directx) {
    //    rgfw_lib.root_module.addCMacro("RGFW_DIRECTX", "");
    //    rgfw_module.linkSystemLibrary("dxgi", .{});
    //    rgfw_module.linkSystemLibrary("d3d11", .{});
    //    rgfw_module.linkSystemLibrary("uuid", .{});
    //    rgfw_module.linkSystemLibrary("d3dcompiler_47", .{});
    //}
    if (optimize == .Debug) {
        rgfw_lib.root_module.addCMacro("RGFW_PRINT_ERRORS", "");
        rgfw_lib.root_module.addCMacro("RGFW_DEBUG", "");
    }
    rgfw_lib.root_module.addCMacro("RGFW_IMPLEMENTATION", "");
    rgfw_module.addCSourceFile(.{
        // FIXME: https://github.com/ziglang/zig/issues/19423
        .file = b.addWriteFiles().add("rgfw.c", "#include <RGFW.h>"),
    });

    //rgfw_module.addOptions("build_options", o[1]);
    rgfw_module.linkLibrary(rgfw_lib);
}
