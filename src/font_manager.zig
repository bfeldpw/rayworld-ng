const std = @import("std");
const cfg = @import("config.zig");
const gfx_impl = @import("gfx_impl.zig");
const c = @cImport({
    @cInclude("stb_truetype.h");
    @cInclude("stb_rect_pack.h");
});

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const FontError = error{
    FontDesignatorUnknown,
    FontLoadingFailed,
    FontMaxNrOfAtlasses,
    FontNameUnknown,
    FontNoneRasterised,
    FontRasterisingFailed,
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// Initialise font manager. This reserves memory for...
pub fn init() void {
    fm_log.info("Initialising font manager", .{});
}

/// Shut down font manager, freeing all allocated memory
pub fn deinit() void {
    fm_log.info("Shutting down font manager", .{});

    {
        var iter = fonts_map.iterator();
        while (iter.next()) |v| {
            allocator.free(v.value_ptr.*);
        }
    }
    fonts_map.deinit();
    {
        var iter = font_char_info_by_id.iterator();
        while (iter.next()) |v| {
            allocator.free(v.value_ptr.*);
        }
    }
    font_char_info_by_id.deinit();
    {
        var iter = font_atlas_by_id.iterator();
        while (iter.next()) |v| {
            allocator.free(v.value_ptr.*);
        }
    }
    font_atlas_by_id.deinit();
    font_atlas_size_by_id.deinit();

    {
        var iter = font_id_by_name.keyIterator();
        while (iter.next()) |v| {
            allocator.free(v.*);
        }
    }
    font_id_by_name.deinit();
    font_timer_by_id.deinit();

    const leaked = gpa.deinit();
    if (leaked) fm_log.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

const TextSize = struct {
    w: f32,
    h: f32,
};

pub inline fn getTimerById() *const std.AutoHashMap(u32, std.time.Timer) {
    return &font_timer_by_id;
}

pub inline fn getIdByName() *const std.StringHashMap(u32) {
    return &font_id_by_name;
}

/// Return width and height of given text in pixel
/// For generic fonts without line breaks consider using <getTextSizeLine>
/// For monospace fonts without line breaks consider using <getTextSizeLineMono>
pub fn getTextSize(text: []const u8, ww: f32) FontError!TextSize {
    if (current.tex_id == 0) {
        fm_log.err("No fonts have been rasterised. Use <addFont> and <rasterise> or <setFont>.", .{});
        return error.FontNoneRasterised;
    }

    var length: f32 = 0.0;
    var length_max: f32 = 0.0;
    var height: f32 = current.font_size;
    var b: c.stbtt_packedchar = undefined;
    for (text) |ch| {
        if (ch == 10) { // Handle line feed
            if (length > length_max) {
                length_max = length;
            }
            length = 0.0;
            height += current.font_size;
        } else {
            b = current.char_info[ch - ascii_first];
            if (ww > 0.0 and b.xadvance + length > ww) { // Handle word wrap
                length = 0.0;
                height += current.font_size;
            }
            length += b.xadvance;
            if (length > length_max) {
                length_max = length;
            }
        }
    }
    if (length > length_max) {
        length_max = length;
    }
    return .{.w=length_max, .h=height};
}

/// Return width and height of given text in pixel. This function might be used
/// for generic fonts without line breaks to enable some optimisations.
/// For generic fonts with line breaks use <getTextSize>
/// For monospace fonts without line breaks consider using <getTextSizeLineMono>
pub fn getTextSizeLine(text: []const u8) FontError!TextSize {
    if (current.tex_id == 0) {
        fm_log.err("No fonts have been rasterised. Use <addFont> and <rasterise> or <setFont>.", .{});
        return error.FontNoneRasterised;
    }

    var length: f32 = 0.0;
    var height: f32 = current.font_size;
    var b: c.stbtt_packedchar = undefined;
    for (text) |ch| {
        b = current.char_info[ch - ascii_first];
        length += b.xadvance;
    }
    return .{.w=length, .h=height};
}

/// Return width and height of given text in pixel. This function might be used
/// for monospace fonts without line breaks to enable some optimisations.
/// For generic fonts with line breaks use <getTextSize>
/// For generic fonts without line breaks consider using <getTextSizeLine>
pub fn getTextSizeLineMono(text: []const u8) FontError!TextSize {
    if (current.tex_id == 0) {
        fm_log.err("No fonts have been rasterised. Use <addFont> and <rasterise> or <setFont>.", .{});
        return error.FontNoneRasterised;
    }

    var length: f32 = 0.0;
    var height: f32 = current.font_size;
    var b: c.stbtt_packedchar = undefined;
    b = current.char_info[text[0] - ascii_first];
    length = b.xadvance * @intToFloat(f32, text.len);

    return .{.w=length, .h=height};
}

pub fn setFont(font_name: []const u8, font_size: f32) !void {
    if (fonts_map.contains(font_name)) {

        // Get font information to use correct baseline
        var font_info: c.stbtt_fontinfo = undefined;
        _ = c.stbtt_InitFont(@ptrCast([*c] c.stbtt_fontinfo, &font_info),
                             @ptrCast([*c]const u8, fonts_map.get(font_name).?), 0);
        const font_scale = c.stbtt_ScaleForPixelHeight(&font_info, font_size);

        var font_ascent: i32 = 0;
        c.stbtt_GetFontVMetrics(&font_info, &font_ascent, 0, 0);
        const baseline = @intToFloat(f32, font_ascent) * font_scale;

        // Setup parameters for current font
        const font_designator = std.fmt.allocPrint(allocator, "{s}_{d:.0}",
                                                   .{font_name, font_size}) catch |e| {
            fm_log.err("{}", .{e});
            return error.FontRasterisingFailed;
        };
        defer allocator.free(font_designator);

        var success = true;
        if (!font_id_by_name.contains(font_designator)) {
            success = false;
        }
        if (font_char_info_by_id.contains(current.tex_id) == false or
            font_atlas_by_id.contains(current.tex_id) == false) {
            success = false;
        }
        if (success) {
            current.font_name = font_name;
            current.font_size = font_size;
            current.tex_id = font_id_by_name.get(font_designator).?;
            current.char_info = font_char_info_by_id.get(current.tex_id).?;
            current.atlas_size = font_atlas_size_by_id.get(current.tex_id).?;
            current.idle_timer = font_timer_by_id.getPtr(current.tex_id).?;
            current.baseline = baseline;
            var t = font_timer_by_id.get(current.tex_id).?;
            t.reset();
        } else {
            if (auto_rasterise) {
                fm_log.debug("Unable to get information about font designator <{s}>", .{font_designator});
                fm_log.debug("You are covered, <auto_rasterise> is enabled", .{});
                rasterise(font_name, font_size, gfx_impl.getNewTextureId()) catch |err| {
                    return err;
                };

            } else {
                fm_log.err("Unable to get information about font designator <{s}>", .{font_designator});
                fm_log.err("Maybe you misspelled, try rasterise first", .{});
                return error.FontDesignatorUnknown;
            }
        }
    } else {
        fm_log.err("Unknown font name <{s}>, maybe you misspelled, otherwise load" ++
                    " first", .{font_name});
        return error.FontNameUnknown;
    }
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn addFont(font_name: []const u8,
               file_name: []const u8) FontError!void {
    fm_log.info("Opening file {s}", .{file_name});
    const file = std.fs.cwd().openFile(file_name, .{}) catch |e| {
        fm_log.err("{}", .{e});
        return FontError.FontLoadingFailed;
    };
    defer file.close();

    const stat = file.stat() catch |e| {
        fm_log.err("{}", .{e});
        return FontError.FontLoadingFailed;
    };
    fm_log.debug("File size: {}", .{stat.size});

    const font_mem = file.reader().readAllAlloc(allocator, stat.size) catch |e| {
        fm_log.err("{}", .{e});
        return FontError.FontLoadingFailed;
    };

    fonts_map.put(font_name, font_mem) catch |e|
    {
        fm_log.err("{}", .{e});
        return FontError.FontLoadingFailed;
    };
    fm_log.debug("Number of fonts: {}", .{fonts_map.count()});
    current.font_name = font_name;

}

pub fn printIdleTimes() void {
    var iter = font_id_by_name.iterator();
    // var iter = font_timer_by_id.iterator();
    while (iter.next()) |v| {
        const tex_id = v.value_ptr.*;
        const name = v.key_ptr.*;
        var timer = font_timer_by_id.get(tex_id).?;
        const t = 1.0e-9 * @intToFloat(f64, timer.read());
        fm_log.debug("Font <{s}>, ID={}, t_idle = {d:.3}s", .{name, tex_id, t});
    }
}

pub fn rasterise(font_name: []const u8, font_size: f32, tex_id: u32) FontError!void {

    // Check, if font with font_name exists
    if (!fonts_map.contains(font_name)) return error.FontNameUnknown;

    // Create and store designator consisting of font_name and the size
    const font_designator = std.fmt.allocPrint(allocator, "{s}_{d:.0}",
                                               .{font_name, font_size}) catch |e| {
        fm_log.err("{}", .{e});
        return error.FontRasterisingFailed;
    };
    fm_log.debug("Rasterising font with size {d:.0} named {s}",
                 .{font_size, font_designator});

    if (font_id_by_name.contains(font_designator)) {
        fm_log.debug("Font <{s}> already rasterised, skipping", .{font_designator});
        allocator.free(font_designator);
    } else {
        // Check for maximum number of font atlasses
        if (font_id_by_name.count() == font_atlas_limit) {
            if (auto_remove) {
                fm_log.debug("Feature <auto_remove> enabled", .{});
                const tex_id_removal = findCandidateForAutoRemoval();

                var t = font_timer_by_id.get(tex_id_removal).?;
                const idle_time = 1.0e-9 * @intToFloat(f64, t.read());
                if (idle_time > auto_remove_idle_time) {
                    fm_log.debug("Auto removing font to be replaced by <{s}>", .{font_designator});
                    try removeFontById(tex_id_removal);
                } else {
                    fm_log.err("Couldn't auto remove font, all fonts seem to be used regarding " ++
                                "minimum idle time at {d:.2}s", .{idle_time});
                    return error.FontMaxNrOfAtlasses;
                }
            } else {
                fm_log.err("Maximum number of rasterised fonts already reached: {}", .{font_atlas_limit});
                return error.FontMaxNrOfAtlasses;
            }
        }

        font_id_by_name.put(font_designator, @intCast(u32, tex_id)) catch |e| {
            fm_log.err("{}", .{e});
            return error.FontRasterisingFailed;
        };

        // Prepare character information such as kerning
        current.char_info = allocator.alloc(c.stbtt_packedchar, ascii_nr) catch |e| {
            fm_log.err("{}", .{e});
            return error.FontRasterisingFailed;
        };
        font_char_info_by_id.put(tex_id, current.char_info) catch |e| {
            fm_log.err("{}", .{e});
            return error.FontRasterisingFailed;
        };

        // Pack atlas. Retry with bigger texture if neccessary
        var atlas_done: bool = false;
        var atlas_scale: usize = 1;
        while (atlas_scale <= font_atlas_scale_max and !atlas_done) : (atlas_scale *= 2) {

            // Prepare atlas array size, free previously allocated
            // memory in case of resizing
            const s = font_atlas_size_default * font_atlas_size_default * atlas_scale * atlas_scale;
            if (atlas_scale > 1) {
                allocator.free(font_atlas_by_id.get(tex_id).?);
                _ = font_atlas_by_id.remove(tex_id);
                _ = font_atlas_size_by_id.remove(tex_id);
            }

            // Allocate memory for the atlas and add reference based
            // on texture id
            const atlas = allocator.alloc(u8, s) catch |e| {
                fm_log.err("{}", .{e});
                return error.FontRasterisingFailed;
            };

            font_atlas_by_id.put(tex_id, atlas) catch |e| {
                fm_log.err("{}", .{e});
                return error.FontRasterisingFailed;
            };
            const atlas_size = @intCast(i32, font_atlas_size_default * atlas_scale);
            font_atlas_size_by_id.put(tex_id, atlas_size) catch |e| {
                fm_log.err("{}", .{e});
                return error.FontRasterisingFailed;
            };

            // Try to pack atlas
            atlas_done = true;
            var pack_context: c.stbtt_pack_context = undefined;
            const r0 = c.stbtt_PackBegin(&pack_context, @ptrCast([*c]u8, atlas),
                                         @intCast(i32, font_atlas_size_default * atlas_scale),
                                         @intCast(i32, font_atlas_size_default * atlas_scale), 0, 1, null);
            if (r0 == 0) {
                fm_log.debug("Could not pack font with texture size {}, trying larger texture size.",
                             .{font_atlas_size_default * atlas_scale});
                atlas_done = false;
            } else {
                c.stbtt_PackSetOversampling(&pack_context, 1, 1);
                const r1 = c.stbtt_PackFontRange(&pack_context, @ptrCast([*c]u8, fonts_map.get(font_name).?),
                                                 0, font_size, ascii_first, ascii_nr,
                                                 @ptrCast([*c]c.stbtt_packedchar, font_char_info_by_id.get(tex_id).?));
                if (r1 == 0) {
                    fm_log.debug("Could not pack font with texture size {}, trying texture size {}.",
                                 .{font_atlas_size_default * atlas_scale,
                                   font_atlas_size_default * atlas_scale * 2});
                    atlas_done = false;
                }
                else {
                    c.stbtt_PackEnd(&pack_context);
                }
            }
        }
        atlas_scale /= 2;

        if (!atlas_done) {
            fm_log.err("Could not pack font {s} with size {d:.0}, try to reduce font size.",
                        .{font_name, font_size});
            fm_log.err("Texture size would have been {}",
                        .{font_atlas_size_default * atlas_scale});
            return error.FontRasterisingFailed;
        } else {
            gfx_impl.createTextureAlpha(font_atlas_size_default * @intCast(u32, atlas_scale),
                                        font_atlas_size_default * @intCast(u32, atlas_scale),
                                        font_atlas_by_id.get(tex_id).?, tex_id);

            const t = std.time.Timer.start() catch |err| {
                fm_log.err("{}", .{err});
                return error.FontRasterisingFailed;
            };
            font_timer_by_id.put(tex_id, t) catch |err| {
                fm_log.err("{}", .{err});
                return error.FontRasterisingFailed;
            };
            current.idle_timer = font_timer_by_id.getPtr(tex_id).?;
            current.tex_id = tex_id;
            try setFont(font_name, font_size);
        }
    }
}

pub fn removeFontByDesignator(name: []const u8) FontError!void {
    var success: bool = true;
    const id = font_id_by_name.get(name);
    if (id == null) {
        success = false;
    } else {
        success = success and font_id_by_name.remove(name);
        // allocator.free(name);
        allocator.free(font_atlas_by_id.get(id.?).?);
        allocator.free(font_char_info_by_id.get(id.?).?);
        success = success and font_atlas_by_id.remove(id.?);
        success = success and font_char_info_by_id.remove(id.?);
        success = success and font_timer_by_id.remove(id.?);
    }
    if (!success) {
        fm_log.err("Couldn't remove font <{s}>, unknown font name", .{name});
        return error.FontNameUnknown;
    } else {
        gfx_impl.releaseTexture(id.?);
    }
}

pub fn removeFontById(id: u32) FontError!void {
    var success: bool = true;

    var font_name: []const u8 = "";
    var iter = font_id_by_name.iterator();
    while (iter.next()) |v| {
        if (v.value_ptr.* == id) {
            font_name = v.key_ptr.*;
            break;
        }
    }

    fm_log.debug("Removing font <{s}> with id {}", .{font_name, id});
    success = success and font_id_by_name.remove(font_name);
    allocator.free(font_name);
    allocator.free(font_atlas_by_id.get(id).?);
    allocator.free(font_char_info_by_id.get(id).?);
    success = success and font_atlas_by_id.remove(id);
    success = success and font_char_info_by_id.remove(id);
    success = success and font_timer_by_id.remove(id);

    if (!success) {
        fm_log.err("Couldn't remove font <{s}> with id {}, unknown id", .{font_name, id});
        return error.FontNameUnknown;
    } else {
        gfx_impl.releaseTexture(id);
    }
}

pub fn renderAtlas() FontError!void {
    if (current.tex_id == 0) {
        fm_log.err("No fonts have been rasterised. Use <addFont> and <rasterise> or <setFont>.", .{});
        return error.FontNoneRasterised;
    }
    gfx_impl.bindTexture(current.tex_id);
    const x0 = 100;
    const x1 = 612;
    const y0 = 100;
    const y1 = 612;
    gfx_impl.addImmediateQuadTextured(x0, y0, x1, y1, 0.0, 0.0, 1.0, 1.0);
}

pub fn renderText(text: []const u8, x: f32, y: f32, ww: f32) FontError!void {
    if (current.tex_id == 0) {
        fm_log.err("No fonts have been rasterised. Use <addFont> and <rasterise> or <setFont>.", .{});
        return error.FontNoneRasterised;
    }

    var glyph_quad: c.stbtt_aligned_quad = undefined;
    var offset_x: f32 = 0.0;
    var offset_y: f32 = current.baseline;

    current.idle_timer.reset();

    gfx_impl.bindTexture(current.tex_id);
    gfx_impl.beginBatchQuadsTextured();
    for (text) |ch| {

        if (ch == 10) { // Handle line feed
            offset_x = 0.0;
            offset_y += current.font_size;
        } else {
            if (ww > 0 and current.char_info[ch - ascii_first].xadvance + offset_x > ww) {
                offset_x = 0.0;
                offset_y += current.font_size;
            }
            c.stbtt_GetPackedQuad(@ptrCast([*c]c.stbtt_packedchar, current.char_info),
                                  current.atlas_size, current.atlas_size,
                                  ch - ascii_first,
                                  &offset_x, &offset_y, &glyph_quad, 0);
            gfx_impl.addBatchQuadTextured(glyph_quad.x0+x, glyph_quad.y0+y, glyph_quad.x1+x, glyph_quad.y1+y,
                                          glyph_quad.s0, glyph_quad.t0, glyph_quad.s1, glyph_quad.t1);
        }
    }
    gfx_impl.endBatch();
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

/// Font manager logging scope
const fm_log = std.log.scoped(.fnt);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){}
          else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Number of relevant ASCII characters
const ascii_nr = 95;
const ascii_first = 32;
const font_atlas_size_default = 32;
const font_atlas_scale_max = 128;

const current = struct {
    var atlas_size: i32 = font_atlas_size_default;
    var baseline: f32 = 0.0;
    var char_info: []c.stbtt_packedchar = undefined;
    var font_name: []const u8 = undefined;
    var font_size: f32 = 16.0;
    var tex_id: u32 = 0;
    var idle_timer: *std.time.Timer = undefined;
};

// Use local variables for config to enable runtime setting for
// unit tests
var auto_rasterise: bool = cfg.fnt.auto_rasterise;
var auto_remove: bool = cfg.fnt.auto_remove;
var auto_remove_idle_time: f64 = cfg.fnt.auto_remove_idle_time;
var font_atlas_limit: u8 = cfg.fnt.font_atlas_limit;

/// Raw font information as read from file
var fonts_map = std.StringHashMap([]u8).init(allocator);

/// Font information like kerning for all rasterised fonts
var font_char_info_by_id = std.AutoHashMap(u32, []c.stbtt_packedchar).init(allocator);

/// Access atlas by given texture id
var font_atlas_by_id = std.AutoHashMap(u32, []u8).init(allocator);

/// Access atlas sizes by given texture id
var font_atlas_size_by_id = std.AutoHashMap(u32, i32).init(allocator);

/// Texture id of font atlas for a given font name
var font_id_by_name = std.StringHashMap(u32).init(allocator);

/// Timer of fonts idle time to decide which font to remove when
/// reaching the font_atlas_limit
var font_timer_by_id = std.AutoHashMap(u32, std.time.Timer).init(allocator);

fn findCandidateForAutoRemoval() u32 {
    var iter = font_timer_by_id.iterator();
    var tex_id_max_idle: u32 = 0;
    var t_max_idle: u64 = 0;
    while (iter.next()) |v| {
        if (v.value_ptr.read() > t_max_idle) {
            t_max_idle = v.value_ptr.read();
            tex_id_max_idle = v.key_ptr.*;
        }
    }
    fm_log.debug("Candidate found with maximum idle time t = {d:.2}s",
                 .{1.0e-9 * @intToFloat(f64, t_max_idle)});
    return tex_id_max_idle;
}

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "font: open font file (failure)" {
    const actual = addFont("non_existing_fond_name", "./this/font/does/not/exist.ttf");
    const expected = FontError.FontLoadingFailed;
    try std.testing.expectError(expected, actual);
    try std.testing.expectEqual(font_atlas_by_id.count(), 0);
    try std.testing.expectEqual(font_char_info_by_id.count(), 0);
    try std.testing.expectEqual(font_id_by_name.count(), 0);
    try std.testing.expectEqual(font_timer_by_id.count(), 0);
    try std.testing.expectEqual(fonts_map.count(), 0);
}

test "font: open font file" {
    try addFont("anka", "resource/AnkaCoder-r.ttf");
    try std.testing.expectEqual(font_atlas_by_id.count(), 0);
    try std.testing.expectEqual(font_char_info_by_id.count(), 0);
    try std.testing.expectEqual(font_id_by_name.count(), 0);
    try std.testing.expectEqual(font_timer_by_id.count(), 0);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: use font without rasterisation (failure)" {
    const expected = error.FontNoneRasterised;
    const actual_0 = getTextSize("42", 0.0);
    try std.testing.expectError(expected, actual_0);
    const actual_1 = getTextSizeLine("42");
    try std.testing.expectError(expected, actual_1);
    const actual_2 = getTextSizeLineMono("42");
    try std.testing.expectError(expected, actual_2);
    const actual_3 = renderAtlas();
    try std.testing.expectError(expected, actual_3);
    const actual_4 = renderText("42", 0.0, 0.0, 0.0);
    try std.testing.expectError(expected, actual_4);
}

test "font: rasterise" {
    font_atlas_limit = 3;
    try rasterise("anka", 16, 1);
    try std.testing.expectEqual(font_atlas_by_id.count(), 1);
    try std.testing.expectEqual(font_char_info_by_id.count(), 1);
    try std.testing.expectEqual(font_id_by_name.count(), 1);
    try std.testing.expectEqual(font_timer_by_id.count(), 1);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: rasterise twice" {
    try rasterise("anka", 16, 1);
    try std.testing.expectEqual(font_atlas_by_id.count(), 1);
    try std.testing.expectEqual(font_char_info_by_id.count(), 1);
    try std.testing.expectEqual(font_id_by_name.count(), 1);
    try std.testing.expectEqual(font_timer_by_id.count(), 1);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: rasterise (failure)" {
    const actual = rasterise("no_font_name", 16, 0);
    const expected = error.FontNameUnknown;
    try std.testing.expectError(expected, actual);
    try std.testing.expectEqual(font_atlas_by_id.count(), 1);
    try std.testing.expectEqual(font_char_info_by_id.count(), 1);
    try std.testing.expectEqual(font_id_by_name.count(), 1);
    try std.testing.expectEqual(font_timer_by_id.count(), 1);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: get text size" {
    const s_0 = try getTextSize("Two\nlines", 0.0);
    try std.testing.expectApproxEqAbs(s_0.w, 40.76, 0.01);
    try std.testing.expectEqual(s_0.h, 32);
    const s_1 = try getTextSizeLine("One line");
    try std.testing.expectApproxEqAbs(s_1.w, 65.22, 0.01);
    try std.testing.expectEqual(s_1.h, 16);
    const s_2 = try getTextSizeLineMono("One line");
    try std.testing.expectApproxEqAbs(s_2.w, 65.22, 0.01);
    try std.testing.expectEqual(s_2.h, 16);
    const s_3 = try getTextSize("One line", 0.0);
    try std.testing.expectApproxEqAbs(s_3.w, 65.22, 0.01);
    try std.testing.expectEqual(s_3.h, 16);
}

test "font: get text size word wrapped" {
    const s_1 = try getTextSize("One line", 35.0);
    try std.testing.expectApproxEqAbs(s_1.w, 32.61, 0.01);
    try std.testing.expectEqual(s_1.h, 32.0);
    const s_2 = try getTextSize("Two\nlns", 35.0);
    try std.testing.expectApproxEqAbs(s_2.w, 24.46, 0.01);
    try std.testing.expectEqual(s_2.h, 32.0);
    const s_3 = try getTextSize("Two\nlines", 35.0);
    try std.testing.expectApproxEqAbs(s_3.w, 32.61, 0.01);
    try std.testing.expectEqual(s_3.h, 48.0);
}

test "font: removal (failure)" {
    const actual = removeFontByDesignator("anka_17");
    const expected = error.FontNameUnknown;
    try std.testing.expectError(expected, actual);
    try std.testing.expectEqual(font_atlas_by_id.count(), 1);
    try std.testing.expectEqual(font_char_info_by_id.count(), 1);
    try std.testing.expectEqual(font_id_by_name.count(), 1);
    try std.testing.expectEqual(font_timer_by_id.count(), 1);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: removal" {
    try removeFontByDesignator("anka_16");
    try std.testing.expectEqual(font_atlas_by_id.count(), 0);
    try std.testing.expectEqual(font_char_info_by_id.count(), 0);
    try std.testing.expectEqual(font_id_by_name.count(), 0);
    try std.testing.expectEqual(font_timer_by_id.count(), 0);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: set font (failure 01)" {
    const actual = setFont("anka_bad", 16);
    const expected = error.FontNameUnknown;
    try std.testing.expectError(expected, actual);

    try std.testing.expectEqual(font_atlas_by_id.count(), 0);
    try std.testing.expectEqual(font_char_info_by_id.count(), 0);
    try std.testing.expectEqual(font_id_by_name.count(), 0);
    try std.testing.expectEqual(font_timer_by_id.count(), 0);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: set font (failure 02)" {
    auto_rasterise = false;
    const actual = setFont("anka", 16);
    const expected = error.FontDesignatorUnknown;
    try std.testing.expectError(expected, actual);

    try std.testing.expectEqual(font_atlas_by_id.count(), 0);
    try std.testing.expectEqual(font_char_info_by_id.count(), 0);
    try std.testing.expectEqual(font_id_by_name.count(), 0);
    try std.testing.expectEqual(font_timer_by_id.count(), 0);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: set font, auto rasterise" {
    auto_rasterise = true;
    try setFont("anka", 16);

    try std.testing.expectEqual(font_atlas_by_id.count(), 1);
    try std.testing.expectEqual(font_char_info_by_id.count(), 1);
    try std.testing.expectEqual(font_id_by_name.count(), 1);
    try std.testing.expectEqual(font_timer_by_id.count(), 1);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: set font" {
    auto_rasterise = false;
    try rasterise("anka", 32, 1);
    try setFont("anka", 16);

    try std.testing.expectEqual(font_atlas_by_id.count(), 2);
    try std.testing.expectEqual(font_char_info_by_id.count(), 2);
    try std.testing.expectEqual(font_id_by_name.count(), 2);
    try std.testing.expectEqual(font_timer_by_id.count(), 2);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: atlas limit (failure)" {
    auto_remove = false;

    try rasterise("anka", 64, 2);

    try std.testing.expectEqual(font_atlas_by_id.count(), 3);
    try std.testing.expectEqual(font_char_info_by_id.count(), 3);
    try std.testing.expectEqual(font_id_by_name.count(), 3);
    try std.testing.expectEqual(font_timer_by_id.count(), 3);
    try std.testing.expectEqual(fonts_map.count(), 1);

    const actual = rasterise("anka", 128, 3);
    const expected = error.FontMaxNrOfAtlasses;
    try std.testing.expectError(expected, actual);

    try std.testing.expectEqual(font_atlas_by_id.count(), 3);
    try std.testing.expectEqual(font_char_info_by_id.count(), 3);
    try std.testing.expectEqual(font_id_by_name.count(), 3);
    try std.testing.expectEqual(font_timer_by_id.count(), 3);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: auto remove time limit (failure)" {
    auto_remove = true;
    auto_remove_idle_time = 100.0;

    const actual = rasterise("anka", 128, 3);
    const expected = error.FontMaxNrOfAtlasses;
    try std.testing.expectError(expected, actual);

    try std.testing.expectEqual(font_atlas_by_id.count(), 3);
    try std.testing.expectEqual(font_char_info_by_id.count(), 3);
    try std.testing.expectEqual(font_id_by_name.count(), 3);
    try std.testing.expectEqual(font_timer_by_id.count(), 3);
    try std.testing.expectEqual(fonts_map.count(), 1);
}

test "font: auto remove" {
    auto_remove = true;
    auto_remove_idle_time = 0.1;
    std.time.sleep(0.2e9);

    try rasterise("anka", 128, 3);

    try std.testing.expectEqual(font_atlas_by_id.count(), 3);
    try std.testing.expectEqual(font_char_info_by_id.count(), 3);
    try std.testing.expectEqual(font_id_by_name.count(), 3);
    try std.testing.expectEqual(font_timer_by_id.count(), 3);
    try std.testing.expectEqual(fonts_map.count(), 1);
}
