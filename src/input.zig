const std = @import("std");
const c = @import("c.zig").c;
const gfx = @import("graphics.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() void {
    // ToDo: errors need to be handled
    _ = c.glfwSetCursorPosCallback(window, processMouseMoveEvent);
    _ = glfwCheckError();
    _ = c.glfwSetKeyCallback(window, processKeyPressEvent);
    _ = glfwCheckError();
    _ = c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    _ = glfwCheckError();
    _ = c.glfwSetCursorPos(window, 0.0, 0.0);
}
//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn processInputs() void {
    var glfw_error: bool = false;

    c.glfwPollEvents();
    glfw_error = glfwCheckError();

    if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) plr.strafe(0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) plr.strafe(-0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) plr.move(0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) plr.move(-0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_E) == c.GLFW_PRESS) plr.moveUpDown(0.05);
    if (c.glfwGetKey(window, c.GLFW_KEY_C) == c.GLFW_PRESS) plr.moveUpDown(-0.05);
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

const log_input = std.log.scoped(.input);

var window: ?*c.GLFWwindow = null;

fn glfwCheckError() bool {
    const code = c.glfwGetError(null);
    if (code != c.GLFW_NO_ERROR) {
        log_input.err("GLFW error code {}", .{code});
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
    log_input.debug("Mouse move event, position: {d:.0}, {d:.0}", .{x, y});
    plr.turn(-@floatCast(f32, x)*0.001);
    plr.lookUpDown(@floatCast(f32, y)*0.001);

    _ = c.glfwSetCursorPos(window, 0.0, 0.0);
}
