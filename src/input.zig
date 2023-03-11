const std = @import("std");
const c = @import("c.zig").c;
const gfx = @import("graphics.zig");
const plr = @import("player.zig");
const sim = @import("sim.zig");

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

pub fn processInputs(frequency: f32) void {
    var glfw_error: bool = false;

    c.glfwPollEvents();
    glfw_error = glfwCheckError();

    if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) plr.strafe(6.0 / frequency);
    if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) plr.strafe(-6.0 / frequency);
    if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) plr.move(6.0 / frequency);
    if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) plr.move(-6.0 / frequency);
    if (c.glfwGetKey(window, c.GLFW_KEY_E) == c.GLFW_PRESS) plr.moveUpDown(3.0 / frequency);
    if (c.glfwGetKey(window, c.GLFW_KEY_C) == c.GLFW_PRESS) plr.moveUpDown(-3.0 / frequency);
    if (c.glfwGetKey(window, c.GLFW_KEY_LEFT) == c.GLFW_PRESS) sim.moveMapLeft();
    if (c.glfwGetKey(window, c.GLFW_KEY_RIGHT) == c.GLFW_PRESS) sim.moveMapRight();
    if (c.glfwGetKey(window, c.GLFW_KEY_UP) == c.GLFW_PRESS) sim.moveMapUp();
    if (c.glfwGetKey(window, c.GLFW_KEY_DOWN) == c.GLFW_PRESS) sim.moveMapDown();
    if (c.glfwGetKey(window, c.GLFW_KEY_F3) == c.GLFW_PRESS) sim.zoomOutMap();
    if (c.glfwGetKey(window, c.GLFW_KEY_F4) == c.GLFW_PRESS) sim.zoomInMap();
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

    if (key == c.GLFW_KEY_F5 and action == c.GLFW_PRESS) sim.timing.decelerate();
    if (key == c.GLFW_KEY_F6 and action == c.GLFW_PRESS) sim.timing.accelerate();
    if (key == c.GLFW_KEY_F7 and action == c.GLFW_PRESS) sim.timing.decreaseFpsTarget();
    if (key == c.GLFW_KEY_F8 and action == c.GLFW_PRESS) sim.timing.increaseFpsTarget();
    if (key == c.GLFW_KEY_H and action == c.GLFW_PRESS) sim.toggleStationHook();
    if (key == c.GLFW_KEY_M and action == c.GLFW_PRESS) sim.toggleMap();
    if (key == c.GLFW_KEY_P and action == c.GLFW_PRESS) sim.togglePause();
    if (key == c.GLFW_KEY_Q and action == c.GLFW_PRESS) c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
}

fn processMouseMoveEvent(win: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    _ = win;
    log_input.debug("Mouse move event, position: {d:.0}, {d:.0}", .{x, y});
    plr.turn(-@floatCast(f32, x)*0.001);
    plr.lookUpDown(@floatCast(f32, y)*0.001);

    _ = c.glfwSetCursorPos(window, 0.0, 0.0);
}
