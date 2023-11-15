const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import("config.zig");
const stats = @import("stats.zig");

//-----------------------------------------------------------------------------//
//   Error Sets / Enums
//-----------------------------------------------------------------------------//

const GraphicsError = error{
    GLFWFailed,
    OpenGLFailed,
    ShaderCompilationFailed,
    ShaderLoadingFailed,
    ShaderLinkingFailed,
};

const AttributeMode = enum {
    None,
    Pxy,
    PxyCrgba
};

const BufferTarget = enum(c_uint) {
    Array = c.GL_ARRAY_BUFFER,
    Element = c.GL_ELEMENT_ARRAY_BUFFER
};

const DrawMode = enum(c_uint) {
    Static = c.GL_STATIC_DRAW,
    Dynamic = c.GL_DYNAMIC_DRAW,
    Stream = c.GL_STREAM_DRAW
};

const PrimitiveMode = enum(c_uint) {
    LineLoop = c.GL_LINE_LOOP,
    Lines = c.GL_LINES,
    Points = c.GL_POINTS,
    Triangles = c.GL_TRIANGLES
};

const ShaderType = enum(c_uint) {
    Fragment = c.GL_FRAGMENT_SHADER,
    Vertex = c.GL_VERTEX_SHADER
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    try initGLFW();
    try initOpenGL();
}

pub fn deinit() void {
    window_resize_callbacks.deinit();

    c.glfwDestroyWindow(window);
    log_gfx.info("Destroying window", .{});
    c.glfwTerminate();
    log_gfx.info("Terminating glfw", .{});

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn getAspect() f32 {
    return aspect;
}

pub inline fn getFPS() f32 {
    return fps;
}

/// Get the active glfw window
pub inline fn getWindow() ?*c.GLFWwindow {
    return window;
}

pub inline fn getWindowHeight() u64 {
    return window_h;
}

pub inline fn getWindowWidth() u64 {
    return window_w;
}

/// Set the frequency of the main loop
pub fn setFpsTarget(f: f32) void {
    if (f > 0.0) {
        frame_time = @intFromFloat(1.0 / f * 1.0e9);
        log_gfx.info("Setting graphics frequency target to {d:.1} Hz", .{f});
    } else {
        log_gfx.warn("Invalid frequency, defaulting to 60Hz", .{});
        frame_time = 16_666_667;
    }
}

pub fn setLineWidth(w: f32) !void {
    if (w != state.line_width) {
        c.glLineWidth(w);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.line_width = w;
    }
}

pub fn setPointSize(s: f32) !void {
    if (s != state.point_size) {
        c.glPointSize(s);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.point_size = s;
    }
}

pub fn setViewport(x: u64, y: u64, w: u64, h: u64) !void {
    c.glViewport(@intCast(x), @intCast(y),
                 @intCast(w), @intCast(h));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn setViewportFull() void {
    c.glViewport(0, 0, @intCast(window_w), @intCast(window_h));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

//-----------------------------------------------------------------------------//
//   Predefined vertex attribute modes
//-----------------------------------------------------------------------------//

pub fn setVertexAttributeMode(m: AttributeMode) !void {
    if (m != state.vertex_attribute_mode) {
        switch (m) {
            .Pxy => {
                c.__glewEnableVertexAttribArray.?(0);
                if (!glCheckError()) return GraphicsError.OpenGLFailed;
                c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), null);
                if (!glCheckError()) return GraphicsError.OpenGLFailed;
            },
            .PxyCrgba => {
                c.__glewEnableVertexAttribArray.?(0);
                if (!glCheckError()) return GraphicsError.OpenGLFailed;
                c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), null);
                if (!glCheckError()) return GraphicsError.OpenGLFailed;
                c.__glewEnableVertexAttribArray.?(1);
                if (!glCheckError()) return GraphicsError.OpenGLFailed;
                c.__glewVertexAttribPointer.?(1, 4, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
                if (!glCheckError()) return GraphicsError.OpenGLFailed;
            },
            else => {}
        }
        state.vertex_attribute_mode = m;
    }
}

//-----------------------------------------------------------------------------//
//   OpenGL Buffer Object Processing
//-----------------------------------------------------------------------------//

pub fn bindVAO(vao: u32) !void {
    if (vao != state.bound_vao) {
        c.__glewBindVertexArray.?(vao);
        state.bound_vao = vao;
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
    }
}

pub fn bindBuffer(target: BufferTarget, vbo: u32) !void {
    c.__glewBindBuffer.?(@intFromEnum(target), vbo);
    state.bound_vbo = vbo;
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn bindEBO(ebo: u32) !void {
    if (ebo != state.bound_ebo) {
        c.__glewBindBuffer.?(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        state.bound_ebo = ebo;
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
    }
}

pub fn bindVBO(vbo: u32) !void {
    if (vbo != state.bound_vbo) {
        c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
        state.bound_vbo = vbo;
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
    }
}

pub fn bindEBOAndBufferData(ebo: u32, n: u32, data: []u32, mode: DrawMode) !void {
    try bindEBO(ebo);
    c.__glewBufferData.?(c.GL_ELEMENT_ARRAY_BUFFER, n*@sizeOf(u32), @ptrCast(data), @intFromEnum(mode));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn bindVBOAndBufferData(vbo: u32, n: u32, data: []f32, mode: DrawMode) !void {
    try bindVBO(vbo);
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, n*@sizeOf(f32), @ptrCast(data), @intFromEnum(mode));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn bindVBOAndBufferSubData(offset: u32, vbo: u32, n: u32, data: []f32) !void {
    try bindVBO(vbo);
    c.__glewBufferSubData.?(c.GL_ARRAY_BUFFER, offset, n*@sizeOf(f32), @ptrCast(data));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn bindVBOAndReserveBuffer(target: BufferTarget, vbo: u32, n: u32, mode: DrawMode) !void {
    try bindBuffer(target, vbo);
    c.__glewBufferData.?(@intFromEnum(target), n*@sizeOf(f32), null, @intFromEnum(mode));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn createBuffer() !u32 {
    var b: u32 = 0;
    c.__glewGenBuffers.?(1, &b);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Buffer object generated, id={}", .{b});
    return b;
}

pub fn createTexture(w: u32, h: u32, data: []u8) !u32 {
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_MIRRORED_REPEAT);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_MIRRORED_REPEAT);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    _ = data;

    var tex: u32 = 0;
    c.glGenTextures(1, &tex);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Texture generated, id={}, size={}x{}", .{tex, w, h});
    return tex;
}

pub fn createVAO() !u32 {
    var vao: u32 = 0;
    c.__glewGenVertexArrays.?(1, &vao);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Vertex array object (VAO) generated, id={}", .{vao});
    return vao;
}

//-----------------------------------------------------------------------------//
//   Drawing
//-----------------------------------------------------------------------------//

pub fn drawArrays(mode: PrimitiveMode, offset: i32, elements: i32) !void {
    c.glDrawArrays(@intFromEnum(mode), offset, elements);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn drawElements(mode: PrimitiveMode, n: i32) !void {
    c.glDrawElements(@intFromEnum(mode), n, c.GL_UNSIGNED_INT, null);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

//-----------------------------------------------------------------------------//
//   Shader Processing
//-----------------------------------------------------------------------------//

pub fn compileShader(src: []u8, t: c_uint) !u32 {

    const id = c.__glewCreateShader.?(t);

    c.__glewShaderSource.?(id, 1, @ptrCast(&src), @alignCast(@ptrCast(c.NULL)));
    c.__glewCompileShader.?(id);

    var success: i32 = 0;
    c.__glewGetShaderiv.?(id, c.GL_COMPILE_STATUS, &success);

    if (success == 0) {
        var info: [512]u8 = undefined;
        c.__glewGetShaderInfoLog.?(id, 512, @alignCast(@ptrCast(c.NULL)), @ptrCast(&info));
        log_gfx.err("Shader could not be compiled: {s}", .{info});
        return GraphicsError.ShaderCompilationFailed;
    } else {
        log_gfx.debug("Shader compiled: id={d:.0}", .{id});
        return id;
    }
}

pub fn createShaderProgram(vs: u32, fs: u32) !u32 {
    const id = c.__glewCreateProgram.?();
    c.__glewAttachShader.?(id, vs);
    c.__glewAttachShader.?(id, fs);
    c.__glewLinkProgram.?(id);

    var success: i32 = 0;
    c.__glewGetProgramiv.?(id, c.GL_LINK_STATUS, &success);

    if (success == 0) {
        var info: [512]u8 = undefined;
        c.__glewGetProgramInfoLog.?(id, 512, @alignCast(@ptrCast(c.NULL)), @ptrCast(&info));
        log_gfx.err("Shader program could not be linked: {s}", .{info});
        return GraphicsError.ShaderLinkingFailed;
    } else {
        c.__glewUseProgram.?(id);
        log_gfx.debug("Shader program created: id={d}", .{id});
        return id;
    }
}

pub fn createShaderProgramFromFiles(vs: []const u8, fs: []const u8) !u32 {
    const vs_id = try loadAndCompileShader(vs, ShaderType.Vertex);
    const fs_id = try loadAndCompileShader(fs, ShaderType.Fragment);
    const sp_id = try createShaderProgram(vs_id, fs_id);
    try deleteShaderObject(vs_id);
    try deleteShaderObject(fs_id);
    return sp_id;
}

pub fn deleteShaderObject(id: u32) !void {
    c.__glewDeleteShader.?(id);
    if (!glCheckError()) {
        log_gfx.err("Unabale to delete shader object, id={d}", .{id});
        return GraphicsError.OpenGLFailed;
    }
}

pub fn deleteShaderProgram(id: u32) !void {
    c.__glewDeleteProgram.?(id);
    if (!glCheckError()) {
        log_gfx.err("Unabale to delete shader program, id={d}", .{id});
        return GraphicsError.OpenGLFailed;
    }
}

pub fn loadAndCompileShader(file_name: []const u8, t: ShaderType) !u32 {
    var shader_src: []u8 = undefined;
    errdefer allocator.free(shader_src);

    try loadShader(file_name, &shader_src);

    const id = try compileShader(shader_src, @intFromEnum(t));
    allocator.free(shader_src);
    return id;
}

pub fn loadShader(file_name: []const u8, src: *[]u8) !void {
    log_gfx.debug("Loading shader {s}", .{file_name});
    const file = std.fs.cwd().openFile(file_name, .{}) catch |e| {
        log_gfx.err("{}", .{e});
        return GraphicsError.ShaderLoadingFailed;
    };
    defer file.close();

    const stat = file.stat() catch |e| {
        log_gfx.err("{}", .{e});
        return GraphicsError.ShaderLoadingFailed;
    };
    if (stat.size > 0) {
        log_gfx.debug("Shader file size: {}", .{stat.size});
        src.* = file.reader().readAllAlloc(allocator, stat.size) catch |e| {
            log_gfx.err("{}", .{e});
            return GraphicsError.ShaderLoadingFailed;
        };
        const last = src.*[stat.size-1];
        log_gfx.debug("Last char: {d}", .{last});

        // Remove last char in case of "\n", "\r", EOF
        if (last == 10 or last == 13 or last == 26) {
            log_gfx.debug("Removing last char", .{});
            src.*[stat.size-1] = 0;
        }
    }
}

pub fn setUniform4f(sp: u32, u: [*c]const u8, a: f32, b: f32, d: f32, e: f32) !void {
    const l: i32 = c.__glewGetUniformLocation.?(sp, u);
    c.__glewUniform4f.?(l, a, b, d, e);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn useShaderProgram(id: u32) !void {
    if (id != state.active_shader_program) {
        c.__glewUseProgram.?(id);
        state.active_shader_program = id;
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
    }
}

pub fn finishFrame() !void {
    c.glfwSwapBuffers(window);
    c.glClearColor(0, 0, 0.1, 1);
    c.glClear(c.GL_COLOR_BUFFER_BIT);

    // Sleep if time step (frame_time) is lower than that of the targeted
    // frequency. Make sure not to have a negative sleep for high frame
    // times.
    const t = timer_main.read();

    fps_stable_count += 1;
    var t_s = frame_time - @as(i64, @intCast(t));
    if (t_s < 0) {
        t_s = 0;
        // log_gfx.debug("Frequency target could not be reached", .{});
        fps_drop_count += 1;
        fps_stable_count = 0;
        if (fps_drop_count > 10) {
            fps_drop_count = 0;
            is_sleep_enabled = false;
            log_gfx.info("Too many fps drops, disabling sleep, frequency target no longer valid", .{});
        }
    }
    if (fps_stable_count > 100) {
        fps_drop_count = 0;
        fps_stable_count = 0;
        if (!is_sleep_enabled) {
            is_sleep_enabled = true;
            log_gfx.info("Fps stable, enabling sleep, frequency target is valid", .{});
        }
    }

    if (is_sleep_enabled) {
        std.time.sleep(@intCast(t_s));
        fps = 1e6 / @as(f32, @floatFromInt(@divTrunc(frame_time, 1_000)));
    } else {
        fps = 1e6 / @as(f32, @floatFromInt(t / 1000));
    }
    timer_main.reset();
}

//-----------------------------------------------------------------------------//
//   Window handling
//-----------------------------------------------------------------------------//

var window_resize_callbacks = std.ArrayList(*const fn (w: u64, h: u64) void).init(allocator);

pub fn addWindowResizeCallback(cb: *const fn (w: u64, h: u64) void ) !void {
    try window_resize_callbacks.append(cb);
    window_resize_callbacks.items[0](window_w, window_h);
}

pub fn isWindowOpen() bool {
    if (c.glfwWindowShouldClose(window) == c.GLFW_TRUE) {
        return false;
    } else {
        return true;
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx = std.log.scoped(.gfx_core);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var window: ?*c.GLFWwindow = null;
var window_w: u64 = 640; // Window width
var window_h: u64 = 480; // Window height
var aspect: f32 = 640 / 480;
var frame_time: i64 = @intFromFloat(1.0 / 5.0 * 1.0e9);
var timer_main: std.time.Timer = undefined;
var is_sleep_enabled: bool = true;
var fps_drop_count: u16 = 0;
var fps_stable_count: u64 = 0;
var fps: f32 = 60;

var draw_call_statistics = stats.PerFrameCounter.init("Draw calls");
var quad_statistics = stats.PerFrameCounter.init("Quads");
var quad_tex_statistics = stats.PerFrameCounter.init("Quads textured");

/// Maximum quad buffer size for rendering
const quads_max = 4096 / cfg.sub_sampling_base * 8; // 4K resolution, minimm width 2px, maximum of 8 lines in each column of a depth layer
/// Maximum depth levels for rendering
const depth_levels = cfg.gfx.depth_levels_max;
/// Active depth levels
var depth_levels_active = std.bit_set.IntegerBitSet(depth_levels).initEmpty();

const shader_ids = std.ArrayList(u8).init(allocator);

const state = struct {
    var active_shader_program: u32 = 0;
    var bound_ebo: u32 = 0;
    var bound_vao: u32 = 0;
    var bound_vbo: u32 = 0;
    var bound_texture: u32 = 0;
    var is_texturing_enabled: bool = false;
    var line_width: f32 = 1.0;
    var point_size: f32 = 1.0;
    var vertex_attribute_mode: AttributeMode = .None;
};

fn glCheckError() bool {
    const code = c.glGetError();
    if (code != c.GL_NO_ERROR) {
        log_gfx.err("GL error code {}", .{code});
        return false;
    }
    return true;
}

fn glfwCheckError() bool {
    const code = c.glfwGetError(null);
    if (code != c.GLFW_NO_ERROR) {
        log_gfx.err("GLFW error code {}", .{code});
        return false;
    }
    return true;
}

fn initGLFW() !void {
    log_gfx.info("Initialising GLFW", .{});
    var glfw_error: bool = false;

    const r = c.glfwInit();

    if (r == c.GLFW_FALSE) {
        glfw_error = glfwCheckError();
        return GraphicsError.GLFWFailed;
    }
    errdefer c.glfwTerminate();

    // Go for core profile
    log_gfx.info("Trying to go for GL core profile", .{});
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 6);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    log_gfx.info("Creating window", .{});
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
    log_gfx.info("Initialising OpenGL ", .{});

    log_gfx.info("-- using GLEW", .{});
    const glew_err = c.glewInit();
    if (c.GLEW_OK != glew_err)
    {
        log_gfx.err("GLEW couldn't be initialised, error: {s}", .{c.glewGetErrorString(glew_err)});
    }
    const ver = c.glGetString(c.GL_VERSION);
    log_gfx.info("-- version {s}", .{ver});

    try setViewport(0, 0,@intCast(window_w), @intCast(window_h));
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
}

fn processWindowResizeEvent(win: ?*c.GLFWwindow, w: c_int, h: c_int) callconv(.C) void {
    log_gfx.debug("Resize triggered by callback", .{});
    log_gfx.info("Setting window size to {}x{}.", .{ w, h });
    _ = win;
    window_w = @intCast(w);
    window_h = @intCast(h);
    aspect = @as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h));

    var i: u32 = 0;
    while (i < window_resize_callbacks.items.len) : (i += 1) {
        window_resize_callbacks.items[i](window_w, window_h);
    }

    // Callback can't return Zig-Error
    setViewport(0, 0, window_w, window_h) catch |e| {
        log_gfx.err("{}", .{e});
        log_gfx.err("Error resizing window ({}x{})", .{ w, h });
    };
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "init_glfw" {
    try initGLFW();
}

test "init_gl" {
    try initOpenGL();
}

test "compile_shader" {
    const fragment_shader_source = "#version 330 core\n" ++
        "out vec4 FragColor;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n" ++
        "}\n";
    var fragment_shader: u32 = 0;
    try compileShader("fragment shader", fragment_shader_source, &fragment_shader, c.GL_FRAGMENT_SHADER);
}

test "set_frequency_invalid_expected" {
    setFpsTarget(0);
    try std.testing.expectEqual(frame_time, @as(i64, 16_666_667));
}

test "set_frequency" {
    setFpsTarget(40);
    try std.testing.expectEqual(frame_time, @as(i64, 25_000_000));
    setFpsTarget(100);
    try std.testing.expectEqual(frame_time, @as(i64, 10_000_000));
}