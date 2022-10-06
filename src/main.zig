const std = @import("std");
const zgui = @import("zgui");
const zgui_glfw = @import("zgui_glfw");
const zgui_opengl = @import("zgui_opengl");
const glfw = @import("glfw");
const gl = @import("gl3.zig");
const Editor = @import("Editor.zig").Editor;

const width = 800;
const height = 800;
const title = "GBASprite Editor";

fn glGetProcAddress(p: ?*anyopaque, proc: [:0]const u8) ?*const anyopaque {
    _ = p;
    return glfw.getProcAddress(proc);
}

pub fn main() void {
    glfw.init(.{}) catch |err| {
        std.log.err("Failed Initialising GLFW: {}", .{err});
        return;
    };

    defer glfw.terminate();

    const window: glfw.Window = glfw.Window.create(width, height, title, null, null, .{
        .context_version_major = 3,
        .context_version_minor = 3,
        .opengl_profile = .opengl_core_profile,
        .opengl_forward_compat = true,
        .cocoa_retina_framebuffer = false,
    }) catch |err| {
        std.log.err("Failed Creating Window: {}", .{err});
        return;
    };

    defer window.destroy();

    glfw.makeContextCurrent(window) catch |err| {
        std.log.err("Cannot make context current: {}", .{err});
        return;
    };
    glfw.swapInterval(1) catch |err| {
        std.log.err("Cannot enable VSync: {}", .{err});
        return;
    };

    gl.load(@as(?*anyopaque, null), glGetProcAddress) catch |err| {
        std.log.err("Failed loading GL functions: {}", .{err});
        return;
    };

    const glsl_version: [:0]const u8 = "#version 330 core";
    zgui.init();
    defer zgui.deinit();

    zgui_glfw.initOpengl(window.handle, true) catch |err| {
        std.log.err("{}", .{err});
        return;
    };
    defer zgui_glfw.deinit();
    zgui_opengl.init(glsl_version) catch |err| {
        std.log.err("{}", .{err});
        return;
    };
    defer zgui_opengl.deinit();

    var e: Editor = .{};
    e.setup();

    zgui.pushStyleVar1f(.{ .idx = .window_rounding, .v = 5.0 });
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 10.0, 10.0 } });
    defer zgui.popStyleVar(.{ .count = 2 });

    while (!window.shouldClose()) {
        glfw.pollEvents() catch |err| {
            std.log.err("Error Capturing Events: {}", .{err});
            return;
        };

        const size = window.getFramebufferSize() catch |err| {
            std.log.err("{}", .{err});
            return;
        };

        zgui_opengl.newFrame();
        zgui_glfw.newFrame();
        zgui.newFrame();

        e.setupScreen(@intToFloat(f32, size.width), @intToFloat(f32, size.height));

        zgui.render();

        gl.viewport(0, 0, @intCast(c_int, size.width), @intCast(c_int, size.height));
        gl.clearColor(0.2, 0.2, 0.2, 1);
        gl.clear(gl.COLOR_BUFFER_BIT);
        zgui_opengl.render(zgui.getDrawData());
        window.swapBuffers() catch |err| {
            std.log.err("Error Swapping Buffers: {}", .{err});
            return;
        };
    }
}
