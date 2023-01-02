const std = @import("std");
// const glfw = @import("glfw");
const c = @import("c.zig").c;

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    std.log.info("Initialising glfw", .{});
    var glfw_error: bool = false;

    const r = c.glfwInit();
    if (r == c.GLFW_FALSE) {
        glfw_error = glfwCheckError();
        return;
    }

    window = c.glfwCreateWindow(@intCast(c_int, window_w), @intCast(c_int, window_h), "rayworld-ng", null, null);
    glfw_error = glfwCheckError();

    c.glfwMakeContextCurrent(window);
    glfw_error = glfwCheckError();

    c.glfwSwapInterval(0);
    glfw_error = glfwCheckError();

    _ = c.glfwSetWindowSizeCallback(window, processWindowResizeEvent);

    std.log.info("Initialising open gl", .{});
    c.glViewport(0, 0, @intCast(c_int, window_w), @intCast(c_int, window_h));
    c.glMatrixMode(c.GL_PROJECTION);
    c.glLoadIdentity();
    c.glOrtho(0, @intToFloat(f64, window_w), 0, @intToFloat(f64, window_h), -1, 1);
}

pub fn deinit() void {
    c.glfwDestroyWindow(window);
    std.log.info("Destroying window", .{});
    c.glfwTerminate();
    std.log.info("Terminating glfw", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn draw() void {
    // Plain old OpenGL fixed function pipeline for testing
    c.glBegin(c.GL_TRIANGLES);
        c.glVertex3f( 100.0, 100.0, 0.0);
        c.glVertex3f( 50.0, 50.0, 0.0);
        c.glVertex3f( 150.0, 50.0, 0.0);
    c.glEnd();
    drawVerticalLine(@intCast(i32,window_w)-10, 10, @intToFloat(f32, window_h)-10);
}

pub fn finishFrame() void {
    c.glfwSwapBuffers(window);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    // Sleep if time step (frame_time) is lower than that of the targeted
    // frequency. Make sure not to have a negative sleep for high frame
    // times.
    const t = timer_main.read();
    var t_s = frame_time - @intCast(i64, t);
    if (t_s < 0) {
        t_s = 0;
        std.log.warn("Update frequency can't be reached", .{});
    }
    std.time.sleep(@intCast(u64, t_s));
    timer_main.reset();
}

pub fn isWindowOpen() bool {
    if (c.glfwWindowShouldClose(window) == c.GLFW_TRUE) {
        return false;
    }
    else {
        return true;
    }
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

/// Get the active glfw window
pub fn getWindow() ?*c.GLFWwindow {
    return window;
}

/// Set the frequency of the main loop
pub fn setFrequency(f: f32) void {
    if (f > 0.0) {
        frame_time = @floatToInt(i64, 1.0/f*1.0e9);
        std.log.info("Setting graphics frequency to {d:.1} Hz", .{f});
    } else {
        std.log.warn("Invalid frequency, defaulting to 60Hz", .{});
        frame_time = 16_666_667;
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

var window: ?*c.GLFWwindow = null;
var window_w: u64 = 640; // Window width
var window_h: u64 = 480; // Window height
var frame_time: i64 = @floatToInt(i64, 1.0/5.0*1.0e9);
var timer_main: std.time.Timer = undefined;

fn drawVerticalLine(x: i32, y0: f32, y1: f32) void {
    c.glBegin(c.GL_LINES);
        c.glVertex2i(x, @floatToInt(c_int, y0));
        c.glVertex2i(x, @floatToInt(c_int, y1));
    c.glEnd();
}

fn glfwCheckError() bool {
    const code = c.glfwGetError(null);
    if (code != c.GLFW_NO_ERROR) {
        std.log.err("GLFW error code {}", .{code});
        return false;
    }
    return true;
}

fn processWindowResizeEvent(win: ?*c.GLFWwindow, w: c_int, h: c_int) callconv(.C) void {
    std.log.debug("Window resized, new size is {}x{}.", .{w, h});
    _ = win;
    window_w = @intCast(u64, w);
    window_h = @intCast(u64, h);
    c.glViewport(0, 0, w, h);
    c.glMatrixMode(c.GL_PROJECTION);
    c.glLoadIdentity();
    c.glOrtho(0, @intToFloat(f64, w), 0, @intToFloat(f64, h), -1, 1);
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "setFrequency" {
    setFrequency(40);
    try std.testing.expectEqual(frame_time, @as(i64, 25_000_000));
    setFrequency(100);
    try std.testing.expectEqual(frame_time, @as(i64, 10_000_000));
    setFrequency(0);
    try std.testing.expectEqual(frame_time, @as(i64, 16_666_667));
}
