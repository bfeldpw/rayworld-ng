const std = @import("std");
const c = @import("c.zig").c;
const stats = @import("stats.zig");

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const GraphicsError = error{
    GLFWFailed,
    OpenGLFailed,
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise glfw, create a window and setup opengl
pub fn init() !void {
    try initGLFW();
    try initOpenGL();
    try allocMemory();

    var value = lines.getPtr(1);
    if (value) |val| {
        for (val.i_verts) |*v| {
            v.* = 0;
        }
        for (val.i_cols) |*v| {
            v.* = 0;
        }
        for (val.n) |*v| {
            v.* = 0;
        }
    }
    var value_textured = lines_textured.getPtr(1);
    if (value_textured) |val| {
        for (val.i_verts) |*v| {
            v.* = 0;
        }
        for (val.i_cols) |*v| {
            v.* = 0;
        }
        for (val.i_texcs) |*v| {
            v.* = 0;
        }
        for (val.n) |*v| {
            v.* = 0;
        }
    }
}

pub fn deinit() void {
    draw_call_statistics.printStats();
    line_statistics.printStats();
    line_tex_statistics.printStats();

    c.glfwDestroyWindow(window);
    log_gfx.info("Destroying window", .{});
    c.glfwTerminate();
    log_gfx.info("Terminating glfw", .{});

    freeMemory();

    const leaked = gpa.deinit();
    if (leaked) log_gfx.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn createTexture(w: u32, h: u32, data: *[]u8) u32 {
    var tex: c.GLuint = 0;
    c.glGenTextures(1, &tex);
    c.glBindTexture(c.GL_TEXTURE_2D, tex);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, 3, @intCast(c_int, w), @intCast(c_int,h), 0,
                   c.GL_RGB, c.GL_UNSIGNED_BYTE, @ptrCast([*c]u8, data.*));
    c.glBindTexture(c.GL_TEXTURE_2D, tex);

    log_gfx.debug("Texture generated with ID={}", .{tex});

    return @intCast(u32, tex);
}

pub fn startBatchLine() void {
    c.glBegin(c.GL_LINES);
}

pub fn startBatchLineTextured() void {
    c.glEnable(c.GL_TEXTURE_2D);
    c.glBegin(c.GL_LINES);
}

pub fn startBatchQuads() void {
    c.glBegin(c.GL_QUADS);
}

pub fn addLine(x0: f32, y0: f32, x1: f32, y1: f32) void {
    c.glVertex3f(x0, y0, 1);
    c.glVertex3f(x1, y1, 1);
}

pub fn addQuad(x0: f32, y0: f32, x1: f32, y1: f32) void {
    c.glVertex2f(x0, y0);
    c.glVertex2f(x1, y0);
    c.glVertex2f(x1, y1);
    c.glVertex2f(x0, y1);
}

pub fn addVerticalLine(x: f32, y0: f32, y1: f32,
                       r: f32, g: f32, b: f32, a: f32,
                       d0: u8) void {

    var value = lines.getPtr(1);
    if (value) |v| {
        const d = depth_levels-d0-1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x;
        v.verts[d][i_v+1] = y0;
        v.verts[d][i_v+2] = x;
        v.verts[d][i_v+3] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = r;
        v.cols[d][i_c+1] = g;
        v.cols[d][i_c+2] = b;
        v.cols[d][i_c+3] = a;
        v.cols[d][i_c+4] = r;
        v.cols[d][i_c+5] = g;
        v.cols[d][i_c+6] = b;
        v.cols[d][i_c+7] = a;
        v.i_verts[d] += 4;
        v.i_cols[d] += 8;
        v.n[d] += 2;
        depth_levels_active.set(d);
        line_statistics.inc();
    }
}

/// Vertical line with gray-scale color grading and constant alpha
pub fn addVerticalLineC2C(x: f32, y0: f32, y1: f32,
                          c0: f32, c1: f32, a: f32, d0: u8) void {

    var value = lines.getPtr(1);
    if (value) |v| {
        const d = depth_levels-d0-1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x;
        v.verts[d][i_v+1] = y0;
        v.verts[d][i_v+2] = x;
        v.verts[d][i_v+3] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = c0;
        v.cols[d][i_c+1] = c0;
        v.cols[d][i_c+2] = c0;
        v.cols[d][i_c+3] = a;
        v.cols[d][i_c+4] = c1;
        v.cols[d][i_c+5] = c1;
        v.cols[d][i_c+6] = c1;
        v.cols[d][i_c+7] = a;
        v.i_verts[d] += 4;
        v.i_cols[d] += 8;
        v.n[d] += 2;
        depth_levels_active.set(d);
        line_statistics.inc();
    }
}

/// Vertical line with gray-scale and alpha color grading
pub fn addVerticalLineCAlpha2Alpha(x: f32, y0: f32, y1: f32,
                                   c0: f32, c1: f32, a0: f32, a1: f32,
                                   d0: u8) void {

    var value = lines.getPtr(1);
    if (value) |v| {
        const d = depth_levels-d0-1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x;
        v.verts[d][i_v+1] = y0;
        v.verts[d][i_v+2] = x;
        v.verts[d][i_v+3] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = c0;
        v.cols[d][i_c+1] = c0;
        v.cols[d][i_c+2] = c0;
        v.cols[d][i_c+3] = a0;
        v.cols[d][i_c+4] = c1;
        v.cols[d][i_c+5] = c1;
        v.cols[d][i_c+6] = c1;
        v.cols[d][i_c+7] = a1;
        v.i_verts[d] += 4;
        v.i_cols[d] += 8;
        v.n[d] += 2;
        depth_levels_active.set(d);
        line_statistics.inc();
    }
}

/// Vertical line with color grading and constant alpha
pub fn addVerticalLineRGB2RGB(x: f32, y0: f32, y1: f32,
                              r0: f32, g0: f32, b0: f32,
                              r1: f32, g1: f32, b1: f32,
                              a: f32, d0: u8) void {

    var value = lines.getPtr(1);
    if (value) |v| {
        const d = depth_levels-d0-1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x;
        v.verts[d][i_v+1] = y0;
        v.verts[d][i_v+2] = x;
        v.verts[d][i_v+3] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = r0;
        v.cols[d][i_c+1] = g0;
        v.cols[d][i_c+2] = b0;
        v.cols[d][i_c+3] = a;
        v.cols[d][i_c+4] = r1;
        v.cols[d][i_c+5] = g1;
        v.cols[d][i_c+6] = b1;
        v.cols[d][i_c+7] = a;
        v.i_verts[d] += 4;
        v.i_cols[d] += 8;
        v.n[d] += 2;
        depth_levels_active.set(d);
        line_statistics.inc();
    }
}


pub fn addVerticalTexturedLine(x: f32, y0: f32, y1: f32,
                               u: f32, v0: f32, v1: f32,
                               r: f32, g: f32, b: f32, a: f32,
                               d0: u8) void {

    var value = lines_textured.getPtr(1);
    if (value) |v| {
        const d = depth_levels-d0-1;
        const i_v = v.i_verts[d];
        v.verts[d][i_v] = x;
        v.verts[d][i_v+1] = y0;
        v.verts[d][i_v+2] = x;
        v.verts[d][i_v+3] = y1;
        const i_c = v.i_cols[d];
        v.cols[d][i_c] = r;
        v.cols[d][i_c+1] = g;
        v.cols[d][i_c+2] = b;
        v.cols[d][i_c+3] = a;
        v.cols[d][i_c+4] = r;
        v.cols[d][i_c+5] = g;
        v.cols[d][i_c+6] = b;
        v.cols[d][i_c+7] = a;
        const i_t = v.i_texcs[d];
        v.texcs[d][i_t] = u;
        v.texcs[d][i_t+1] = v0;
        v.texcs[d][i_t+2] = u;
        v.texcs[d][i_t+3] = v1;
        v.i_verts[d] += 4;
        v.i_cols[d] += 8;
        v.i_texcs[d] += 4;
        v.n[d] += 2;
        depth_levels_active.set(d);
        line_statistics.inc();
        line_tex_statistics.inc();
    }
}

pub fn addVerticalLineAO(x: f32, y0: f32, y1: f32,
                         col_dark: f32, col_light: f32, col_alpha: f32,
                         d: u8) void {

    const d_y=y1-y0;
    const d_c=col_light-col_dark;

    addVerticalLineCAlpha2Alpha(x, y0, y0+d_y*0.05, col_dark, col_dark+d_c*0.5, col_alpha, col_alpha*0.8, d);
    addVerticalLineCAlpha2Alpha(x, y0+d_y*0.05, y0+d_y*0.1, col_dark+d_c*0.5, col_dark+d_c*0.8, col_alpha*0.8, col_alpha*0.3, d);
    addVerticalLineCAlpha2Alpha(x, y0+d_y*0.1, y0+d_y*0.3, col_dark+d_c*0.8, col_light, col_alpha*0.3, col_alpha*0, d);
    addVerticalLineCAlpha2Alpha(x, y0+d_y*0.7, y0+d_y*0.9, col_light, col_dark+d_c*0.8, col_alpha*0, col_alpha*0.3, d);
    addVerticalLineCAlpha2Alpha(x, y0+d_y*0.9, y0+d_y*0.95, col_dark+d_c*0.8, col_dark+d_c*0.5, col_alpha*0.3, col_alpha*0.8, d);
    addVerticalLineCAlpha2Alpha(x, y0+d_y*0.95, y1, col_dark+d_c*0.5, col_dark, col_alpha*0.8, col_alpha, d);
}

pub fn endBatch() void {
    c.glEnd();
}

pub fn endBatchTextured() void {
    c.glEnd();
    c.glDisable(c.GL_TEXTURE_2D);
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

pub fn finishFrame() !void {
    c.glfwSwapBuffers(window);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

    // Sleep if time step (frame_time) is lower than that of the targeted
    // frequency. Make sure not to have a negative sleep for high frame
    // times.
    const t = timer_main.read();

    fps_stable_count += 1;
    var t_s = frame_time - @intCast(i64, t);
    if (t_s < 0) {
        t_s = 0;
        log_gfx.debug("Frequency target could not be reached", .{});
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
        std.time.sleep(@intCast(u64, t_s));
        fps = 1e6 / @intToFloat(f32, @divTrunc(frame_time, 1_000));
    } else {
        fps = 1e6 / @intToFloat(f32, t / 1000);
    }
    timer_main.reset();
}

pub fn setColor4(r: f32, g: f32, b: f32, a: f32) void {
    c.glColor4f(r, g, b, a);
}

pub fn renderFrame() !void {
    var iter = depth_levels_active.iterator(.{});
    while (iter.next()) |d| {
        c.glEnableClientState(c.GL_VERTEX_ARRAY);
        c.glEnableClientState(c.GL_COLOR_ARRAY);
        c.glEnableClientState(c.GL_TEXTURE_COORD_ARRAY);
        c.glEnable(c.GL_TEXTURE_2D);
        var value_textured = lines_textured.getPtr(1);
        if (value_textured) |v| {
            c.glVertexPointer(2, c.GL_FLOAT, 0, @ptrCast([*c]const f32, &v.verts[d]));
            c.glColorPointer(4, c.GL_FLOAT, 0, @ptrCast([*c]const f32, &v.cols[d]));
            c.glTexCoordPointer(2, c.GL_FLOAT, 0, @ptrCast([*c]const f32, &v.texcs[d]));
            c.glDrawArrays(c.GL_LINES, 0, @intCast(c_int, v.n[d]));
            if (!glCheckError()) return GraphicsError.OpenGLFailed;
            v.i_verts[d] = 0;
            v.i_cols[d] = 0;
            v.i_texcs[d] = 0;
            v.n[d] = 0;
            draw_call_statistics.inc();
        }
        c.glDisableClientState(c.GL_TEXTURE_COORD_ARRAY);
        c.glDisable(c.GL_TEXTURE_2D);
        var value = lines.getPtr(1);
        if (value) |v| {
            c.glVertexPointer(2, c.GL_FLOAT, 0, @ptrCast([*c]const f32, &v.verts[d]));
            c.glColorPointer(4, c.GL_FLOAT, 0, @ptrCast([*c]const f32, &v.cols[d]));
            c.glDrawArrays(c.GL_LINES, 0, @intCast(c_int, v.n[d]));
            if (!glCheckError()) return GraphicsError.OpenGLFailed;
            v.i_verts[d] = 0;
            v.i_cols[d] = 0;
            v.n[d] = 0;
            draw_call_statistics.inc();
        }
        c.glDisableClientState(c.GL_VERTEX_ARRAY);
        c.glDisableClientState(c.GL_COLOR_ARRAY);
        c.glDisableClientState(c.GL_TEXTURE_COORD_ARRAY);
    }
    const r = std.bit_set.Range{.start=0, .end=depth_levels-1};
    depth_levels_active.setRangeValue(r, false);

    draw_call_statistics.finishFrame();
    line_statistics.finishFrame();
    line_tex_statistics.finishFrame();
}

pub fn setActiveTexture(tex: u32) void {
    c.glBindTexture(c.GL_TEXTURE_2D, @intCast(c.GLuint, tex));
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

pub fn getFPS() f32 {
    return fps;
}

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
pub fn setFrequencyTarget(f: f32) void {
    if (f > 0.0) {
        frame_time = @floatToInt(i64, 1.0/f*1.0e9);
        log_gfx.info("Setting graphics frequency target to {d:.1} Hz", .{f});
    } else {
        log_gfx.warn("Invalid frequency, defaulting to 60Hz", .{});
        frame_time = 16_666_667;
    }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx = std.log.scoped(.gfx);

var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
// var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var window: ?*c.GLFWwindow = null;
var window_w: u64 = 640; // Window width
var window_h: u64 = 480; // Window height
var frame_time: i64 = @floatToInt(i64, 1.0/5.0*1.0e9);
var timer_main: std.time.Timer = undefined;
var is_sleep_enabled: bool = true;
var fps_drop_count: u16 = 0;
var fps_stable_count: u64 = 0;
var fps: f32 = 60;

var draw_call_statistics = stats.PerFrameCounter.init("Draw calls");
var line_statistics = stats.PerFrameCounter.init("Lines");
var line_tex_statistics = stats.PerFrameCounter.init("Lines textured");

const lines_max = 4096*10; // 4K resolution

const depth_levels = 30;
var depth_levels_active = std.bit_set.IntegerBitSet(depth_levels).initEmpty();

const Lines = struct {
    verts: [depth_levels][lines_max*2*2]f32,
    cols:  [depth_levels][lines_max*2*4]f32,
    i_verts: [depth_levels]u32,
    i_cols:  [depth_levels]u32,
    n: [depth_levels]u32,
};

const TexturedLines = struct {
    verts: [depth_levels][lines_max*2*2]f32,
    cols:  [depth_levels][lines_max*2*4]f32,
    texcs: [depth_levels][lines_max*2*2]f32,
    i_verts: [depth_levels]u32,
    i_cols:  [depth_levels]u32,
    i_texcs: [depth_levels]u32,
    n: [depth_levels]u32,
};

var lines          = std.AutoHashMap(u8, Lines).init(allocator);
var lines_textured = std.AutoHashMap(u8, TexturedLines).init(allocator);

fn allocMemory() !void {
    lines.put(1, .{.verts=undefined, .cols=undefined,
                   .i_verts=undefined, .i_cols=undefined, .n=undefined}) catch |e| {
        log_gfx.err("Allocation error ", .{});
        return e;
    };
    errdefer lines.deinit();
    lines_textured.put(1, .{.verts=undefined, .cols=undefined, .texcs=undefined,
                            .i_verts=undefined, .i_cols=undefined, .i_texcs=undefined, .n=undefined}) catch |e| {
        log_gfx.err("Allocation error ", .{});
        return e;
    };
    errdefer lines_textured.deinit();
}

fn freeMemory() void {
    lines.deinit();
    lines_textured.deinit();
}

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

    window = c.glfwCreateWindow(@intCast(c_int, window_w), @intCast(c_int, window_h), "rayworld-ng", null, null);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;
    errdefer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;

    c.glfwSwapInterval(0);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;

    _ = c.glfwSetWindowSizeCallback(window, processWindowResizeEvent);
    if (!glfwCheckError()) return GraphicsError.GLFWFailed;
}

fn initOpenGL() !void {
    log_gfx.info("Initialising OpenGL ", .{});
    c.glViewport(0, 0, @intCast(c_int, window_w), @intCast(c_int, window_h));
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    c.glMatrixMode(c.GL_PROJECTION);
    c.glLoadIdentity();
    c.glOrtho(0, @intToFloat(f64, window_w), @intToFloat(f64, window_h), 0, -1, 20);
    if (!glCheckError()) return GraphicsError.OpenGLFailed;

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    // c.glTexEnvf(c.GL_TEXTURE_ENV, c.GL_TEXTURE_ENV_MODE, c.GL_ADD);
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
    c.glOrtho(0, @intToFloat(f64, w), @intToFloat(f64, h), 0, -1, 20);

    // Callback can't return Zig-Error
    if (!glCheckError()) {
        log_gfx.err("Error resizing window ({}x{})", .{w, h});
    }
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "setFrequency" {
    setFrequencyTarget(40);
    try std.testing.expectEqual(frame_time, @as(i64, 25_000_000));
    setFrequencyTarget(100);
    try std.testing.expectEqual(frame_time, @as(i64, 10_000_000));
    setFrequencyTarget(0);
    try std.testing.expectEqual(frame_time, @as(i64, 16_666_667));
}
