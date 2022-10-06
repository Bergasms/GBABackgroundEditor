const std = @import("std");
const zgui = @import("lib/zgui/build.zig");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("Editor", "src/main.zig");

    const glfw = @import("lib/zgui/examples/deps/mach-glfw/build.zig");
    exe.addPackage(glfw.pkg);
    glfw.link(b, exe, .{
        .vulkan = false,
        .metal = false,
        .opengl = true,
    });

    exe.linkLibC(); //To compile imgui
    exe.linkLibCpp(); // To compile imgui
    zgui.link_imgui(exe);

    if (exe.target.isDarwin()) {
        exe.addFrameworkPath(thisDir() ++ "/lib/vulkan/macOS/Frameworks");
        exe.linkFramework("vulkan");
        exe.addRPath(thisDir() ++ "/lib/vulkan/macOS/Frameworks");
    }

    exe.addPackage(zgui.zgui);
    exe.addPackage(zgui.zgui_glfw); //Make sure to add glfw as dependency (Prefered binding is mach_glfw)
    exe.addPackage(zgui.zgui_opengl); //Add OpenGL support for Imgui
    exe.addPackage(zgui.zgui_vulkan); //Add OpenGL support for Imgui

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

inline fn thisDir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}
