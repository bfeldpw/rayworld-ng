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

const BufferTarget = enum(c_uint) {
    Array = c.GL_ARRAY_BUFFER,
    Element = c.GL_ELEMENT_ARRAY_BUFFER
};

const DrawMode = enum(c_uint) {
    Static = c.GL_STATIC_DRAW,
    Dynamic = c.GL_DYNAMIC_DRAW,
    Stream = c.GL_STREAM_DRAW
};

pub const PrimitiveMode = enum(c_uint) {
    LineLoop = c.GL_LINE_LOOP,
    Lines = c.GL_LINES,
    Points = c.GL_POINTS,
    Triangles = c.GL_TRIANGLES,
    TriangleFan = c.GL_TRIANGLE_FAN,
    TriangleStrip = c.GL_TRIANGLE_STRIP
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
    state.is_set_uniform4f.deinit();

    c.glfwDestroyWindow(window);
    log_gfx.info("Destroying window", .{});
    c.glfwTerminate();
    log_gfx.info("Terminating glfw", .{});

    buffering_statistics.printStats();
    draw_call_statistics.printStats();
    fbo_bind_statistics.printStats();
    shader_program_statistics.printStats();
    tex_bind_statistics.printStats();
    uniform_update_statistics.printStats();
    vbo_bind_statistics.printStats();

    const leaked = gpa.deinit();
    if (leaked == .leak) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn getStatsBytesBuffered() u64 {
    return buffering_statistics.getCount();
}

pub inline fn getStatsDrawCalls() u64 {
    return draw_call_statistics.getCount();
}

pub inline fn getStatsFboBinds() u64 {
    return fbo_bind_statistics.getCount();
}

pub inline fn getStatsShaderProgramSwitches() u64 {
    return shader_program_statistics.getCount();
}

pub inline fn getStatsTextureBinds() u64 {
    return tex_bind_statistics.getCount();
}

pub inline fn getStatsVboBinds() u64 {
    return vbo_bind_statistics.getCount();
}

pub inline fn getStatsUniformUpdates() u64 {
    return uniform_update_statistics.getCount();
}

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

pub inline fn getWindowHeight() u32 {
    return window_h;
}

pub inline fn getWindowWidth() u32 {
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

pub fn setViewport(x: u32, y: u32, w: u32, h: u32) !void {
    c.glViewport(@intCast(x), @intCast(y),
                 @intCast(w), @intCast(h));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub inline fn setViewportFull() !void {
    try setViewport(0, 0, @intCast(window_w), @intCast(window_h));
}

//-----------------------------------------------------------------------------//
//   OpenGL Vertex Attribute handling
//-----------------------------------------------------------------------------//

pub fn disableVertexAttributes(a: u32) !void {
    std.debug.assert(a < 16);
    // if (state.is_enabled_vertex_attrib.isSet(a)) {
        c.__glewDisableVertexAttribArray.?(a);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.is_enabled_vertex_attrib.unset(a);
    // }
}

pub fn enableVertexAttributes(a: u32) !void {
    std.debug.assert(a < 16);
    // if (!state.is_enabled_vertex_attrib.isSet(a)) {
        c.__glewEnableVertexAttribArray.?(a);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.is_enabled_vertex_attrib.set(a);
    // }
}

pub fn setupVertexAttributesUInt32(id: u32, size: i32, nr: i32, offset: u32) !void {
    c.__glewVertexAttribIPointer.?(id, size, c.GL_UNSIGNED_INT, nr * @sizeOf(u32),
                                   @ptrFromInt(offset * @sizeOf(u32)));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn setupVertexAttributesFloat(id: u32, size: i32, nr: i32, offset: u32) !void {
    c.__glewVertexAttribPointer.?(id, size, c.GL_FLOAT, c.GL_FALSE, nr * @sizeOf(f32),
                                  @ptrFromInt(offset * @sizeOf(f32)));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
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

pub inline fn unbindVAO() !void {
    try bindVAO(0);
}

pub fn bindEBO(ebo: u32) !void {
    // if (ebo != state.bound_ebo) {
        c.__glewBindBuffer.?(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        state.bound_ebo = ebo;
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
    // }
}

pub fn bindVBO(vbo: u32) !void {
    if (vbo != state.bound_vbo) {
        c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.bound_vbo = vbo;
        vbo_bind_statistics.inc();
    }
}

pub fn bindEBOAndBufferData(ebo: u32, n: u32, data: []u32, mode: DrawMode) !void {
    try bindEBO(ebo);
    c.__glewBufferData.?(c.GL_ELEMENT_ARRAY_BUFFER, n*@sizeOf(u32), @ptrCast(data), @intFromEnum(mode));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    buffering_statistics.add(n*4);
}

pub fn bindVBOAndBufferData(vbo: u32, n: u32, data: []f32, mode: DrawMode) !void {
    try bindVBO(vbo);
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, n*@sizeOf(f32), @ptrCast(data), @intFromEnum(mode));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    buffering_statistics.add(n*4);
}

pub fn bindVBOAndBufferSubData(comptime T: type, offset: u32, vbo: u32, n: u32, data: []T) !void {
    try bindVBO(vbo);
    c.__glewBufferSubData.?(c.GL_ARRAY_BUFFER, offset, n*@sizeOf(T), @ptrCast(data));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    buffering_statistics.add(n * @sizeOf(T));
}

pub fn bindVBOAndReserveBuffer(comptime T: type, target: BufferTarget, vbo: u32, n: u32, mode: DrawMode) !void {
    try bindVBO(vbo);
    c.__glewBufferData.?(@intFromEnum(target), n*@sizeOf(T), null, @intFromEnum(mode));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    buffering_statistics.add(n * @sizeOf(T));
}

pub fn genBuffer() !u32 {
    var b: u32 = 0;
    c.__glewGenBuffers.?(1, &b);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Buffer object generated, id={}", .{b});
    return b;
}

pub fn deleteBuffer(b: u32) !void {
    c.__glewDeleteBuffers.?(1, &b);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn bindTexture(tex: u32) !void {
    if (tex != state.bound_texture) {
        c.glBindTexture(c.GL_TEXTURE_2D, tex);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.bound_texture = tex;
        tex_bind_statistics.inc();
    }
}

pub fn createTextureAlpha(w: u32, h: u32, data: []u8, tex: u32) !void {
    try bindTexture(tex);
    log_gfx.debug("Texture to be created with size={}x{}", .{w, h});

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED,
                   @intCast(w), @intCast(h), 0,
                   c.GL_RED, c.GL_UNSIGNED_BYTE, data.ptr);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Texture created with size={}x{}", .{w, h});
}

/// Create a texture, which is basically genTexture (getting an OpenGL
/// texture object), but then setting up the texture parameters and
/// uploading the the texture data
pub fn createTexture(w: u32, h: u32, data: []u8) !u32 {

    const tex: u32 = try genTexture();
    try bindTexture(tex);

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_MIRRORED_REPEAT);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_MIRRORED_REPEAT);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_SRGB, @intCast(w), @intCast(h),
                   0, c.GL_RGB, c.GL_UNSIGNED_BYTE, data.ptr);
    c.__glewGenerateMipmap.?(c.GL_TEXTURE_2D);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Texture created, size={}x{}", .{w, h});
    return tex;
}

pub fn genTexture() !u32 {
    var tex: u32 = 0;
    c.glGenTextures(1, &tex);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    log_gfx.debug("Texture object generated, id={}", .{tex});
    return tex;
}

pub fn deleteTexture(tex: u32) !void {
    c.glDeleteTextures(1, &tex);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    log_gfx.debug("Texture object deleted, id={}", .{tex});
}

pub fn genVAO() !u32 {
    var vao: u32 = 0;
    c.__glewGenVertexArrays.?(1, &vao);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Vertex array object (VAO) generated, id={}", .{vao});
    return vao;
}

//-----------------------------------------------------------------------------//
//   Framebuffer handling
//-----------------------------------------------------------------------------//

/// High level framebuffer data, including texture
pub const fb_data = struct {
    fbo: u32,
    tex: u32,
    w_vp: u32, // viewport width
    h_vp: u32, // viewport height
    w: u32,
    h: u32
};

pub fn disableGammaCorrectionFBO() !void {
    if (state.is_fbo_gamma_correction_enabled) {
        c.glDisable(c.GL_FRAMEBUFFER_SRGB);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.is_fbo_gamma_correction_enabled = false;
    }
}

pub fn enableGammaCorrectionFBO() !void {
    if (!state.is_fbo_gamma_correction_enabled) {
        c.glEnable(c.GL_FRAMEBUFFER_SRGB);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.is_fbo_gamma_correction_enabled = true;
    }
}

pub fn bindFBO(fbo: u32) !void {
    if (fbo != state.bound_fbo) {
        c.__glewBindFramebuffer.?(c.GL_FRAMEBUFFER, fbo);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.bound_fbo = fbo;
        fbo_bind_statistics.inc();
    }
}

pub fn checkFramebuffer(fbo: u32) !void {
    try bindFBO(fbo);
    if (c.__glewCheckFramebufferStatus.?(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE) {
        log_gfx.err("Framebuffer id={} is not complete", .{fbo});
        return GraphicsError.OpenGLFailed;
    }
}

pub fn clearFramebuffer() !void {
    c.glClearColor(0, 0, 0, 1);
    c.glClear(c.GL_COLOR_BUFFER_BIT);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

pub fn genFBO() !u32 {
    var b: u32 = 0;
    c.__glewGenFramebuffers.?(1, &b);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    log_gfx.debug("Framebuffer object generated, id={}", .{b});

    return b;
}

/// High level function to create a framebuffer including texture
pub fn createFramebuffer(w: u32, h: u32) !fb_data {
    var fb = fb_data{ .fbo = 0, .tex = 0, .w = 0, .h = 0, .w_vp = 0, .h_vp = 0};

    fb.w = w;
    fb.h = h;
    fb.w_vp = w;
    fb.h_vp = h;

    fb.fbo = try genFBO();

    fb.tex = try genTexture();
    c.glBindTexture(c.GL_TEXTURE_2D, fb.tex);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_BORDER);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_BORDER);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB32F, @intCast(w), @intCast(h),
                   0, c.GL_RGB, c.GL_UNSIGNED_BYTE, null);

    c.__glewBindFramebuffer.?(c.GL_FRAMEBUFFER, fb.fbo);
    c.__glewFramebufferTexture2D.?(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, fb.tex, 0);

    try checkFramebuffer(fb.fbo);

    c.__glewBindFramebuffer.?(c.GL_FRAMEBUFFER, 0);

    log_gfx.debug("Framebuffer with texture created, size={}x{}", .{w, h});

    return fb;
}

pub fn deleteFBO(fbo: u32) !void {
    c.__glewDeleteFrameBuffers.?(1, &fbo);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
}

//-----------------------------------------------------------------------------//
//   Drawing
//-----------------------------------------------------------------------------//

pub inline fn compressColor(r: f32, g: f32, b: f32, a: f32) u32 {
    const a_u: u32 = @as(u32, @intFromFloat(a * 255.0)) << 24;
    const b_u: u32 = @as(u32, @intFromFloat(b * 255.0)) << 16;
    const g_u: u32 = @as(u32, @intFromFloat(g * 255.0)) << 8;
    const r_u: u32 = @as(u32, @intFromFloat(r * 255.0));
    return r_u + g_u + b_u + a_u;
}

pub inline fn compressGrey(g: f32, a: f32) u32 {
    const a_u: u32 = @as(u32, @intFromFloat(a * 255.0)) << 24;
    const g0: u32 = @as(u32, @intFromFloat(g * 255.0));
    const g1: u32 = @as(u32, @intFromFloat(g * 255.0)) << 8;
    const g2: u32 = @as(u32, @intFromFloat(g * 255.0)) << 16;

    return g0 + g1 + g2 + a_u;
}

pub fn drawArrays(mode: PrimitiveMode, offset: i32, elements: i32) !void {
    c.glDrawArrays(@intFromEnum(mode), offset, elements);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    draw_call_statistics.inc();
}

pub fn drawElements(mode: PrimitiveMode, n: i32) !void {
    c.glDrawElements(@intFromEnum(mode), n, c.GL_UNSIGNED_INT, null);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    draw_call_statistics.inc();
}

//-----------------------------------------------------------------------------//
//   Shader Processing
//-----------------------------------------------------------------------------//

pub fn compileShader(src: []const u8, t: c_uint) !u32 {

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

pub fn setUniform1f(sp: u32, u: [*c]const u8, a: f32) !void {
    try useShaderProgram(sp);
    const l: i32 = c.__glewGetUniformLocation.?(sp, u);
    c.__glewUniform1f.?(l, a);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    uniform_update_statistics.inc();
}

pub fn setUniform4f(sp: u32, u: []const u8, a: f32, b: f32, d: f32, e: f32) !void {
    if (state.is_set_uniform4f.contains(@ptrCast(u))) {
        const v = state.is_set_uniform4f.get(@ptrCast(u)).?;
        if (sp == v.sp and v.a == a and v.b == b and v.d == d and v.e == e) {
            return;
        } else {
            try state.is_set_uniform4f.put(u, .{.sp = sp, .a = a, .b = b, .d = d, .e = e});
        }
    } else {
        try state.is_set_uniform4f.put(u, .{.sp = sp, .a = a, .b = b, .d = d, .e = e});
    }
    try useShaderProgram(sp);
    const l: i32 = c.__glewGetUniformLocation.?(sp, @ptrCast(u));
    c.__glewUniform4f.?(l, a, b, d, e);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;
    uniform_update_statistics.inc();
}

pub fn useShaderProgram(id: u32) !void {
    if (id != state.active_shader_program) {
        c.__glewUseProgram.?(id);
        if (!glCheckError()) return GraphicsError.OpenGLFailed;
        state.active_shader_program = id;
        shader_program_statistics.inc();
    }
}

pub fn finishFrame() !void {
    c.glfwSwapBuffers(window);
    try clearFramebuffer();

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

    buffering_statistics.finishFrame();
    draw_call_statistics.finishFrame();
    fbo_bind_statistics.finishFrame();
    shader_program_statistics.finishFrame();
    tex_bind_statistics.finishFrame();
    vbo_bind_statistics.finishFrame();
    uniform_update_statistics.finishFrame();
}

//-----------------------------------------------------------------------------//
//   Window handling
//-----------------------------------------------------------------------------//

var window_resize_callbacks = std.ArrayList(*const fn (w: u32, h: u32) void).init(allocator);

pub fn addWindowResizeCallback(cb: *const fn (w: u32, h: u32) void ) !void {
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
var window_w: u32 = 640; // Window width
var window_h: u32 = 480; // Window height
var aspect: f32 = 640 / 480;
var frame_time: i64 = @intFromFloat(1.0 / 5.0 * 1.0e9);
var timer_main: std.time.Timer = undefined;
var is_sleep_enabled: bool = true;
var fps_drop_count: u16 = 0;
var fps_stable_count: u64 = 0;
var fps: f32 = 60;

var buffering_statistics = stats.PerFrameCounter.init("Data buffering (bytes)");
var draw_call_statistics = stats.PerFrameCounter.init("Draw calls");
var fbo_bind_statistics = stats.PerFrameCounter.init("FBO binds");
var shader_program_statistics = stats.PerFrameCounter.init("Shader program switches");
var tex_bind_statistics = stats.PerFrameCounter.init("Texture binds");
var vbo_bind_statistics = stats.PerFrameCounter.init("VBO binds");
var uniform_update_statistics = stats.PerFrameCounter.init("Uniform updates");

const Uniform4fType = struct {
    sp: u32,
    a: f32,
    b: f32,
    d: f32,
    e: f32
};

const state = struct {
    var active_shader_program: u32 = 0;
    var bound_ebo: u32 = 0;
    var bound_fbo: u32 = 0;
    var boudn_tex: u32 = 0;
    var bound_vao: u32 = 0;
    var bound_vbo: u32 = 0;
    var bound_texture: u32 = 0;
    var is_texturing_enabled: bool = false;
    var is_fbo_gamma_correction_enabled: bool = false;
    var line_width: f32 = 1.0;
    var point_size: f32 = 1.0;
    var is_enabled_vertex_attrib = std.bit_set.IntegerBitSet(16).initEmpty();
    var is_set_uniform4f = std.StringHashMap(Uniform4fType).init(allocator);
};

fn glCheckError() bool {
    const code = c.glGetError();
    if (code != c.GL_NO_ERROR) {
        switch (code) {
            c.GL_INVALID_ENUM => log_gfx.err("GL error, code {}, INVALID_ENUM", .{code}),
            c.GL_INVALID_VALUE => log_gfx.err("GL error, code {}, INVALID_VALUE", .{code}),
            c.GL_INVALID_OPERATION => log_gfx.err("GL error, code {}, INVALID_OPERATION", .{code}),
            c.GL_STACK_OVERFLOW => log_gfx.err("GL error, code {}, STACK_OVERFLOW", .{code}),
            c.GL_STACK_UNDERFLOW => log_gfx.err("GL error, code {}, STACK_UNDERFLOW", .{code}),
            c.GL_OUT_OF_MEMORY => log_gfx.err("GL error, code {}, OUT_OF_MEMORY", .{code}),
            c.GL_INVALID_FRAMEBUFFER_OPERATION => log_gfx.err("GL error, code {}, INVALID_FRAMEBUFFER_OPERATION", .{code}),
            else => log_gfx.err("GL error, code {}", .{code})
        }
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
    c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, c.GL_TRUE);

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

    c.glfwSwapInterval(1);
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

    var m: i32 = 0;
    c.glGetIntegerv(c.GL_MAX_VERTEX_ATTRIBS, &m);
    if (m < 16) {
        log_gfx.warn("Be aware that the mandatory number of " ++
                     "vertex attribute arrays is not supported on " ++
                     "your system: {}/16. This might cause problems " ++
                     "depending on the programs specific graphics engine.", .{m});
    }

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

test "compile_shader_vert" {
    const vertex_shader_source = "#version 330 core\n" ++
        "layout (location = 0) in vec4 pos;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   gl_Position = pos;\n" ++
        "}\n";
    const vertex_shader = try compileShader(vertex_shader_source, c.GL_VERTEX_SHADER);
    try std.testing.expect(vertex_shader > 0);
}

test "compile_shader_frag" {
    const fragment_shader_source = "#version 330 core\n" ++
        "out vec4 FragColor;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n" ++
        "}\n";
    const fragment_shader = try compileShader(fragment_shader_source, c.GL_FRAGMENT_SHADER);
    try std.testing.expect(fragment_shader > 0);
}

test "create_shader_program" {
    const vertex_shader_source = "#version 330 core\n" ++
        "layout (location = 0) in vec4 pos;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   gl_Position = pos;\n" ++
        "}\n";
    const vertex_shader = try compileShader(vertex_shader_source, c.GL_VERTEX_SHADER);

    const fragment_shader_source = "#version 330 core\n" ++
        "out vec4 FragColor;\n" ++
        "\n" ++
        "void main()\n" ++
        "{\n" ++
        "   FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);\n" ++
        "}\n";
    const fragment_shader = try compileShader(fragment_shader_source, c.GL_FRAGMENT_SHADER);

    const shader_program = try createShaderProgram(vertex_shader, fragment_shader);
    try std.testing.expect(shader_program > 0);
}

test "generate_framebuffer" {
    const fbo = try genFBO();
    try std.testing.expect(fbo > 0);
}

test "create_framebuffer" {
    const fb_dat = try createFramebuffer(100, 100);
    try std.testing.expect(fb_dat.fbo > 0);
    try std.testing.expect(fb_dat.h == 100);
    try std.testing.expect(fb_dat.w == 100);
    try std.testing.expect(fb_dat.h_vp == 100);
    try std.testing.expect(fb_dat.w_vp == 100);
    try std.testing.expect(fb_dat.tex > 0);
}

test "compress_color" {
    try std.testing.expectEqual(0x04030201, compressColor(1.0/255.0, 2.0/255.0, 3.0/255.0, 4.0/255.0));
}

test "compress_grey" {
    try std.testing.expectEqual(0xFF2A2A2A, compressGrey(42.0/255.0, 1.0));
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

test "set_line_width" {
    const w0 = 3;
    try setLineWidth(w0);
    var w: f32 = 1;
    c.glGetFloatv(c.GL_LINE_WIDTH, &w);
    try std.testing.expect(w == w0);
}

test "set_point_size" {
    const s0 = 3;
    try setPointSize(s0);
    var s: f32 = 1;
    c.glGetFloatv(c.GL_POINT_SIZE, &s);
    try std.testing.expect(s == s0);
}

test "set_viewport" {
    try setViewport(10, 20, 100, 200);
    var v = [4]i32{0, 0, 0, 0};
    c.glGetIntegerv(c.GL_VIEWPORT, &v);
    try std.testing.expect(v[0] == 10);
    try std.testing.expect(v[1] == 20);
    try std.testing.expect(v[2] == 100);
    try std.testing.expect(v[3] == 200);
}
