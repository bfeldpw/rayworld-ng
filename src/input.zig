const std = @import("std");
const c = @import("c.zig").c;
const gfx = @import("graphics.zig");
const plr = @import("player.zig");

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn processInputs() void {
    var glfw_error: bool = false;

    c.glfwPollEvents();
    glfw_error = glfwCheckError();

    if (c.glfwGetKey(window, c.GLFW_KEY_Q) == c.GLFW_PRESS) c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
    if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) plr.moveX(-0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) plr.moveX(0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) plr.moveY(0.1);
    if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) plr.moveY(-0.1);
}

fn glfwCheckError() bool {
    const code = c.glfwGetError(null);
    if (code != c.GLFW_NO_ERROR) {
        std.log.err("GLFW error code {}", .{code});
        return false;
    }
    return true;
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
