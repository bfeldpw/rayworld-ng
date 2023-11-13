const std = @import("std");
const c = @import("c.zig").c;
const gfx_core = @import("gfx_core.zig");
const plr = @import("player.zig");
const rw_gui = @import("rw_gui.zig");
const sim = @import("sim.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    // ToDo: errors need to be handled
    _ = c.glfwSetCursorPosCallback(window, processMouseMoveEvent);
    _ = glfwCheckError();
    _ = c.glfwSetKeyCallback(window, processKeyPressEvent);
    _ = glfwCheckError();
    _ = c.glfwSetScrollCallback(window, processScrollEvent);
    _ = glfwCheckError();
    _ = c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
    _ = glfwCheckError();
    _ = c.glfwSetCursorPos(window, 0.0, 0.0);

    try gfx_core.addWindowResizeCallback(&handleWindowResize);
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn processInputs(frequency: f32) void {
    var glfw_error: bool = false;

    c.glfwPollEvents();
    glfw_error = glfwCheckError();

    if (c.glfwGetKey(window, c.GLFW_KEY_LEFT_CONTROL) != c.GLFW_PRESS) {
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
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn getCursorPos(x: *f64, y: *f64) void {
    c.glfwGetCursorPos(window, @ptrCast(x), @ptrCast(y));
}

pub inline fn isMouseButtonLeftPressed() bool {
    return c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_PRESS;
}

var is_f1: bool = false;
pub inline fn getF1() bool {
    return is_f1;
}

var is_f2: bool = false;
pub inline fn getF2() bool {
    return is_f2;
}

pub inline fn getMouseState() MouseState {
    return mouse_state;
}

pub fn resetStates() void {
    mouse_state.wheel = 0.0;
}

pub inline fn setWindow(win: ?*c.GLFWwindow) void {
    window = win;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_input = std.log.scoped(.input);

var window: ?*c.GLFWwindow = null;
var is_edit_mode_enabled = false;

const MouseState = struct {
    wheel: f32 = 0.0,
};
var mouse_state: MouseState = .{};

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
    // _ = mods;

    if (key == c.GLFW_KEY_F1 and action == c.GLFW_PRESS) is_f1 = is_f1 != true;
    if (key == c.GLFW_KEY_F2 and action == c.GLFW_PRESS) is_f2 = is_f2 != true;
    if (key == c.GLFW_KEY_F5 and action == c.GLFW_PRESS) sim.timing.decelerate();
    if (key == c.GLFW_KEY_F6 and action == c.GLFW_PRESS) sim.timing.accelerate();
    if (key == c.GLFW_KEY_F7 and action == c.GLFW_PRESS) sim.timing.decreaseFpsTarget();
    if (key == c.GLFW_KEY_F8 and action == c.GLFW_PRESS) sim.timing.increaseFpsTarget();
    if (key == c.GLFW_KEY_E and mods == c.GLFW_MOD_CONTROL and action == c.GLFW_PRESS) {
        rw_gui.toggleEditMode();
        is_edit_mode_enabled = is_edit_mode_enabled != true;
        if (is_edit_mode_enabled) {
            _ = c.glfwSetCursorPos(window, @floatFromInt(gfx_core.getWindowWidth()/2),
                                           @floatFromInt(gfx_core.getWindowHeight()/2));
        } else {
            _ = c.glfwSetCursorPos(window, 0.0, 0.0);
        }
    }
    if (key == c.GLFW_KEY_H and action == c.GLFW_PRESS) sim.toggleStationHook();
    if (key == c.GLFW_KEY_M and action == c.GLFW_PRESS) sim.toggleMap();
    if (key == c.GLFW_KEY_P and action == c.GLFW_PRESS) sim.togglePause();
    if (key == c.GLFW_KEY_Q and action == c.GLFW_PRESS) c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
}

fn processMouseMoveEvent(win: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    _ = win;
    if (is_edit_mode_enabled) {
        var cur_x: f64 = 0.0;
        var cur_y: f64 = 0.0;
        const c_x: [*c]f64 = &cur_x;
        const c_y: [*c]f64 = &cur_y;
        const w: f64 = @floatFromInt(gfx_core.getWindowWidth());
        const h: f64 = @floatFromInt(gfx_core.getWindowHeight());
        c.glfwGetCursorPos(window, c_x, c_y);
        if (c_x.* < 0.0) c_x.* = 0.0;
        if (c_y.* < 0.0) c_y.* = 0.0;
        if (c_x.* > w) c_x.* = w;
        if (c_y.* > h) c_y.* = h;
        c.glfwSetCursorPos(window, cur_x, cur_y);
    } else {
        log_input.debug("Mouse move event, position: {d:.0}, {d:.0}", .{x, y});

        // prevent jumping player orientation on window resize
        if (!is_resized) {
            plr.turn(@floatCast(x * -0.001));
            plr.lookUpDown(@floatCast(y * 0.001));
        }
        is_resized = false;
        _ = c.glfwSetCursorPos(window, 0.0, 0.0);
    }
}

var is_resized = false;

fn processScrollEvent(win: ?*c.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    _ = win;
    // _ = x;
    mouse_state.wheel = @floatCast(y);
    log_input.debug("Mouse scroll event, offset: {d:.0}, {d:.0}", .{x, y});
}

fn  handleWindowResize(w: u64, h: u64) void {
    // prevent jumping player orientation on window resize
    is_resized = true;
    log_input.debug("Window resize callback triggered, w = {}, h = {}", .{w, h});
}
