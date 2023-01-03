const std = @import("std");
const c = @import("c.zig").c;
const gfx = @import("graphics.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() void {
    _ = c.glfwSetCursorPosCallback(window, processMouseMoveEvent);
    _ = glfwCheckError();
    _ = c.glfwSetKeyCallback(window, processKeyPressEvent);
    _ = glfwCheckError();
    _ = c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    _ = glfwCheckError();
}
//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn processInputs() void {
    var glfw_error: bool = false;

    c.glfwPollEvents();
    glfw_error = glfwCheckError();

    if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) plr.moveX(-0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) plr.moveX(0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) plr.moveY(0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) plr.moveY(-0.1);
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub fn setWindow(win: ?*c.GLFWwindow) void {
    window = win;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

var window: ?*c.GLFWwindow = null;

fn glfwCheckError() bool {
    const code = c.glfwGetError(null);
    if (code != c.GLFW_NO_ERROR) {
        std.log.err("GLFW error code {}", .{code});
        return false;
    }
    return true;
}

fn processKeyPressEvent(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    _ = win;
    _ = scancode;
    _ = mods;

    if (key == c.GLFW_KEY_Q and action == c.GLFW_PRESS) c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
}

fn processMouseMoveEvent(win: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    _ = win;
    std.log.debug("Mouse move event, position: {d:.0}, {d:.0}", .{x, y});
    plr.turn(std.math.sign(@floatCast(f32, x-1300))*0.01);

    _ = c.glfwSetCursorPos(window, 0.0, 0.0);
}
