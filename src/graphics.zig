const std = @import("std");
// const glfw = @import("glfw");
const c = @cImport({
    @cInclude("GL/gl.h");
    @cInclude("GLFW/glfw3.h");
});

pub fn init() !void {
    std.log.info("Initialising glfw", .{});
    var glfw_error: bool = false;

    const r = c.glfwInit();
    if (r == c.GLFW_FALSE) {
        glfw_error = glfwCheckError();
        return;
    }

    // Create our window
    window = c.glfwCreateWindow(640, 480, "bfe-next", null, null);
    glfw_error = glfwCheckError();

    // try glfw.makeContextCurrent(window);
    c.glfwMakeContextCurrent(window);
    glfw_error = glfwCheckError();
}

pub fn deinit() void {
    c.glfwDestroyWindow(window);
    std.log.info("Destroying window", .{});
    c.glfwTerminate();
    std.log.info("Terminating glfw", .{});
}

pub fn run() !void {
    var glfw_error: bool = false;

    var timer_main = try std.time.Timer.start();
    // Wait for the user to close the window.
    while (c.glfwWindowShouldClose(window) == 0) {

        // try glfw.pollEvents();
        c.glfwPollEvents();
        glfw_error = glfwCheckError();

        // if (window.getKey(glfw.Key.q) == .press) window.setShouldClose(true);
        std.log.debug("1s gone by", .{});

        c.glClear(c.GL_COLOR_BUFFER_BIT);
        c.glfwSwapBuffers(window);

        const t = timer_main.read();
        std.time.sleep(frame_time - t);
        timer_main.reset();
        // c.glfwSetWindowShouldClose(window, 1);
    }
}

pub fn getWindow() ?*c.GLFWwindow {
    return window;
}

pub fn setFrequency(f: f32) void {
    if (f > 0.0) {
        frame_time = @floatToInt(u64, 1.0/f*1.0e9);
    } else {
        std.log.warn("Invalid frequency, defaulting to 60Hz", .{});
        frame_time = 16_666_667;
    }
}

var window: ?*c.GLFWwindow = null;
var frame_time: u64 = @floatToInt(u64, 1.0/5.0*1.0e9);

fn glfwCheckError() bool {
    const code = c.glfwGetError(null);
    if (code != c.GLFW_NO_ERROR) {
        std.log.err("GLFW could not be intialised, error code {}", .{code});
        return false;
    }
    return true;
}

test "setFrequency" {
    setFrequency(40);
    try std.testing.expectEqual(frame_time, 25_000_000);
    setFrequency(100);
    try std.testing.expectEqual(frame_time, 10_000_000);
    setFrequency(0);
    try std.testing.expectEqual(frame_time, 16_666_667);
}
