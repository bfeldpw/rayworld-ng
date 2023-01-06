const std = @import("std");
// const glfw = @import("glfw");
const c = @import("c.zig").c;

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    log_gfx.info("Initialising glfw", .{});
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
    glfw_error = glfwCheckError();

    log_gfx.info("Initialising open gl", .{});
    c.glViewport(0, 0, @intCast(c_int, window_w), @intCast(c_int, window_h));
    c.glMatrixMode(c.GL_PROJECTION);
    c.glLoadIdentity();
    c.glOrtho(0, @intToFloat(f64, window_w), @intToFloat(f64, window_h), 0, -1, 1);

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
}

pub fn deinit() void {
    c.glfwDestroyWindow(window);
    log_gfx.info("Destroying window", .{});
    c.glfwTerminate();
    log_gfx.info("Terminating glfw", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn startBatchLine() void {
    c.glBegin(c.GL_LINES);
}

pub fn startBatchQuads() void {
    c.glBegin(c.GL_QUADS);
}

pub fn addLine(x0: f32, y0: f32, x1: f32, y1: f32) void {
    c.glVertex2f(x0, y0);
    c.glVertex2f(x1, y1);
}

pub fn addLineColor3(x0: f32, y0: f32, x1: f32, y1: f32,
                     r0: f32, g0: f32, b0: f32,
                     r1: f32, g1: f32, b1: f32) void {
    c.glColor3f(r0, g0, b0);
    c.glVertex2f(x0, y0);
    c.glColor3f(r1, g1, b1);
    c.glVertex2f(x1, y1);
}

pub fn addQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    c.glVertex2f(x0, y0);
    c.glVertex2f(x1, y0);
    c.glVertex2f(x1, y1);
    c.glVertex2f(x0, y1);
}

pub fn endBatch() void {
    c.glEnd();
}

pub fn drawLine(x0: f32, y0: f32, x1: f32, y1: f32) void {
    c.glBegin(c.GL_LINES);
        c.glVertex2f(x0, y0);
        c.glVertex2f(x1, y1);
    c.glEnd();
}

pub fn drawQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    c.glBegin(c.GL_QUADS);
        c.glVertex2f(x0, y0);
        c.glVertex2f(x1, y0);
        c.glVertex2f(x1, y1);
        c.glVertex2f(x0, y1);
    c.glEnd();
}

pub fn drawTriangle(x0: f32, y0: f32, x1: f32, y1: f32, x2: f32, y2: f32) void {
    c.glBegin(c.GL_TRIANGLES);
        c.glVertex2f(x0, y0);
        c.glVertex2f(x1, y1);
        c.glVertex2f(x2, y2);
    c.glEnd();
}

pub fn drawVerticalLine(x: f32, y0: f32, y1: f32) void {
    c.glBegin(c.GL_LINES);
        c.glVertex2f(x, y0);
        c.glVertex2f(x, y1);
    c.glEnd();
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
        log_gfx.warn("Update frequency can't be reached", .{});
    }
    std.time.sleep(@intCast(u64, t_s));
    timer_main.reset();
}

pub fn setColor3(r: f32, g: f32, b: f32) void {
    c.glColor3f(r, g, b);
}

pub fn setColor4(r: f32, g: f32, b: f32, a: f32) void {
    c.glColor4f(r, g, b, a);
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

pub fn getWindowHeight() u64 {
    return window_h;
}

pub fn getWindowWidth() u64 {
    return window_w;
}

/// Set the frequency of the main loop
pub fn setFrequency(f: f32) void {
    if (f > 0.0) {
        frame_time = @floatToInt(i64, 1.0/f*1.0e9);
        log_gfx.info("Setting graphics frequency to {d:.1} Hz", .{f});
    } else {
        log_gfx.warn("Invalid frequency, defaulting to 60Hz", .{});
        frame_time = 16_666_667;
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx = std.log.scoped(.gfx);

var window: ?*c.GLFWwindow = null;
var window_w: u64 = 640; // Window width
var window_h: u64 = 480; // Window height
var frame_time: i64 = @floatToInt(i64, 1.0/5.0*1.0e9);
var timer_main: std.time.Timer = undefined;

fn glfwCheckError() bool {
    const code = c.glfwGetError(null);
    if (code != c.GLFW_NO_ERROR) {
        log_gfx.err("GLFW error code {}", .{code});
        return false;
    }
    return true;
}

fn processWindowResizeEvent(win: ?*c.GLFWwindow, w: c_int, h: c_int) callconv(.C) void {
    log_gfx.debug("Resize triggered by callback", .{});
    log_gfx.info("Setting window size to {}x{}.", .{w, h});
    _ = win;
    window_w = @intCast(u64, w);
    window_h = @intCast(u64, h);
    c.glViewport(0, 0, w, h);
    c.glMatrixMode(c.GL_PROJECTION);
    c.glLoadIdentity();
    c.glOrtho(0, @intToFloat(f64, w), @intToFloat(f64, h), 0, -1, 1);
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
