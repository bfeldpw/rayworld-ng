const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const GraphicsError = error{
    GLFWFailed,
    OpenGLFailed,
    ShaderCompilationFailed,
    ShaderLinkingFailed,
};

pub fn main() !void {

    try init();
    defer deinit();

    while(c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {

        c.__glewUseProgram.?(shader_program);

        c.__glewBindVertexArray.?(vao);

        // const verts = [9]f32 {
        //     -1.5, -1.5, 0.0,
        //      1.5, -1.5, 0.0,
        //      1.0,  1.5, 0.0,
        // };
        // c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
        // c.__glewBufferData.?(c.GL_ARRAY_BUFFER, 9, &verts, c.GL_STATIC_DRAW);

        // c.__glewVertexAttribPointer.?(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
        // c.__glewEnableVertexAttribArray.?(0);

        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
        c.__glewBindVertexArray.?(0);

        c.glfwSwapBuffers(window);
        c.glClearColor(0, 0, 0.1, 1);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glfwPollEvents();
        _ = glfwCheckError();
    }
}

var window: ?*c.GLFWwindow = null;
var window_w: u64 = 640; // Window width
var window_h: u64 = 480; // Window height
var aspect: f32 = 640 / 480;

var shader_program: u32 = 0;
var vao: u32 = 0;
var vbo: u32 = 0;

fn deinit() void {
    c.glfwDestroyWindow(window);
    std.log.info("Destroying window", .{});
    c.glfwTerminate();
    std.log.info("Terminating glfw", .{});
}

fn init() !void {
    try initGLFW();
    try initOpenGL();
    // try initShadersLoad();
    try initShadersLoad();

    _ = c.glfwSetKeyCallback(window, processKeyPressEvent);
    _ = glfwCheckError();
}

fn initGLFW() !void {
    std.log.info("Initialising GLFW", .{});
    var glfw_error: bool = false;

    const r = c.glfwInit();

    if (r == c.GLFW_FALSE) {
        glfw_error = glfwCheckError();
        return GraphicsError.GLFWFailed;
    }
    errdefer c.glfwTerminate();

    // Go for core profile
    std.log.info("Trying to go for GL core profile", .{});
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    std.log.info("Creating window", .{});
    window = c.glfwCreateWindow(@intCast(window_w), @intCast(window_h), "rayworld-ng", null, null);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;
    errdefer c.glfwDestroyWindow(window);

    aspect = @as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h));

    c.glfwMakeContextCurrent(window);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;

    c.glfwSwapInterval(0);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;

    _ = c.glfwSetWindowSizeCallback(window, processWindowResizeEvent);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;
}

fn initOpenGL() !void {
    std.log.info("Initialising OpenGL ", .{});

    std.log.info("-- using GLEW", .{});
    const glew_err = c.glewInit();
    if (c.GLEW_OK != glew_err)
    {
        std.log.err("GLEW couldn't be initialised, error: {s}", .{c.glewGetErrorString(glew_err)});
    }
    const ver = c.glGetString(c.GL_VERSION);
    std.log.info("-- version {s}", .{ver});

    c.glViewport(0, 0, @intCast(window_w), @intCast(window_h));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    std.log.debug("-- generating vertex buffer objects (VBOs)", .{});
    c.__glewGenBuffers.?(1, &vbo);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    std.log.debug("-- generating vertex array objects (VAOs)", .{});
    c.__glewGenVertexArrays.?(1, &vao);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    c.__glewBindVertexArray.?(vao);

    const verts = [9]f32 {
        -0.5, -0.5, 0.0,
         0.5, -0.5, 0.0,
         0.0,  0.5, 0.0,
    };
    c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, 9*@sizeOf(f32), &verts, c.GL_STATIC_DRAW);

    c.__glewVertexAttribPointer.?(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
    c.__glewEnableVertexAttribArray.?(0);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

fn compileShader(name: []const u8, src: []const u8, id: *u32, t: c_uint) !void {

    std.log.debug("{s}", .{src});
    id.* = c.__glewCreateShader.?(t);

    c.__glewShaderSource.?(id.*, 1, @ptrCast(&src), @alignCast(@ptrCast(c.NULL)));
    c.__glewCompileShader.?(id.*);

    var success: i32 = 0;
    c.__glewGetShaderiv.?(id.*, c.GL_COMPILE_STATUS, &success);

    if (success == 0) {
        var info: [512]u8 = undefined;
        c.__glewGetShaderInfoLog.?(id.*, 512, @alignCast(@ptrCast(c.NULL)), @ptrCast(&info));
        std.log.err("Shader could not be compiled: {s}", .{info});
        return GraphicsError.ShaderCompilationFailed;
    } else {
        std.log.debug("-- Shader compiled: {s}", .{name});
    }
}

fn initShadersLoad() !void {
    std.log.info("Compiling shaders", .{});

    var vertex_shader: u32 = 0;
    var vertex_shader_src: []u8 = undefined;
    try loadShader("/home/bfeld/projects/rayworld-ng/resource/shader/base.vert",
                   &vertex_shader_src);
    std.log.debug("{s}", .{vertex_shader_src});
    try compileShader("vs", vertex_shader_src, &vertex_shader, c.GL_VERTEX_SHADER);

    var fragment_shader: u32 = 0;
    var fragment_shader_src: []u8 = undefined;
    try loadShader("/home/bfeld/projects/rayworld-ng/resource/shader/base.frag",
                   &fragment_shader_src);

    try compileShader("fs", fragment_shader_src, &fragment_shader, c.GL_FRAGMENT_SHADER);
    std.log.info("Creating shader programs", .{});
    // try setupShaderProgram("shader program", &shader_program, vertex_shader, fragment_shader);
    shader_program = c.__glewCreateProgram.?();
    c.__glewAttachShader.?(shader_program, vertex_shader);
    c.__glewAttachShader.?(shader_program, fragment_shader);
    c.__glewLinkProgram.?(shader_program);

    var success: i32 = 0;
    c.__glewGetProgramiv.?(shader_program, c.GL_LINK_STATUS, &success);

    if (success == 0) {
        var info: [512]u8 = undefined;
        c.__glewGetProgramInfoLog.?(shader_program, 512, @alignCast(@ptrCast(c.NULL)), @ptrCast(&info));
        std.log.err("Shader program could not be linked: {s}", .{info});
        return GraphicsError.ShaderLinkingFailed;
    } else {
        std.log.debug("-- Shader program created: ", .{});
    }

    c.__glewDeleteShader.?(vertex_shader);
    c.__glewDeleteShader.?(fragment_shader);
}

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn loadShader(file_name: []const u8, src: *[]u8) !void {
    std.log.info("Opening file {s}", .{file_name});
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    const stat = try file.stat();
    if (stat.size > 0) {
        std.log.debug("Shader file size: {}", .{stat.size});
        src.* = try file.reader().readAllAlloc(allocator, stat.size);
        const last = src.*[stat.size-1];
        std.log.debug("Last char: {d}", .{last});

        // Remove last char in case of "\n", "\r", EOF
        if (last == 10 or last == 13 or last == 26) {
            std.log.debug("Removing last char", .{});
            src.*[stat.size-1] = 0;
        }
    }
}

fn initShaders() !void {
    std.log.info("Compiling shaders", .{});
    const vertex_shader_source = "#version 330 core\n" ++
        "layout (location = 0) in vec3 aPos;\n" ++
        "void main()\n" ++
        "{\n" ++
        "   gl_Position = vec4(aPos, 1.0);\n" ++
        "}\n";
    var vertex_shader: u32 = 0;
    try compileShader("vertex shader", vertex_shader_source, &vertex_shader, c.GL_VERTEX_SHADER);

    const fragment_shader_source = "#version 330 core\n" ++
        "out vec4 FragColor;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n" ++
        "}\n";
    var fragment_shader: u32 = 0;
    try compileShader("fragment shader", fragment_shader_source, &fragment_shader, c.GL_FRAGMENT_SHADER);

    std.log.info("Creating shader programs", .{});
    try setupShaderProgram("shader program", &shader_program, vertex_shader, fragment_shader);

    c.__glewDeleteShader.?(vertex_shader);
    c.__glewDeleteShader.?(fragment_shader);
}

fn glCheckError() bool {
    const code = c.glGetError();
    if (code != c.GL_NO_ERROR) {
        std.log.err("GL error code {}", .{code});
        return false;
    }
    return true;
}

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

fn processWindowResizeEvent(win: ?*c.GLFWwindow, w: c_int, h: c_int) callconv(.C) void {
    std.log.debug("Resize triggered by callback", .{});
    std.log.info("Setting window size to {}x{}.", .{ w, h });
    _ = win;
    window_w = @intCast(w);
    window_h = @intCast(h);
    aspect = @as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h));
    c.glViewport(0, 0, w, h);
    // c.glMatrixMode(c.GL_PROJECTION);
    // c.glLoadIdentity();
    // c.glOrtho(0, @floatFromInt(w), @floatFromInt(h), 0, -1, 20);

    // Callback can't return Zig-Error
    if (!glCheckError()) {
        std.log.err("Error resizing window ({}x{})", .{ w, h });
    }
}

fn setupShaderProgram(name: []const u8, id: *u32, vs: u32, fs: u32) !void {
    id.* = c.__glewCreateProgram.?();
    c.__glewAttachShader.?(id.*, vs);
    c.__glewAttachShader.?(id.*, fs);
    c.__glewLinkProgram.?(id.*);

    var success: i32 = 0;
    c.__glewGetProgramiv.?(id.*, c.GL_LINK_STATUS, &success);

    if (success == 0) {
        var info: [512]u8 = undefined;
        c.__glewGetProgramInfoLog.?(id.*, 512, @alignCast(@ptrCast(c.NULL)), @ptrCast(&info));
        std.log.err("Shader program could not be linked: {s}", .{info});
        return GraphicsError.ShaderLinkingFailed;
    } else {
        std.log.debug("-- Shader program created: {s}", .{name});
    }
}
