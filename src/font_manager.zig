const std = @import("std");
const cfg = @import("config.zig");
const gfx = @import("graphics.zig");
const c = @cImport({
    @cInclude("GL/gl.h");
    @cInclude("stb_truetype.h");
    @cInclude("stb_rect_pack.h");
});

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const FontError = error{
    FontLoadingFailed,
    FontNameUnknown,
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
        var iter = fonts_char_info.iterator();
        while (iter.next()) |v| {
            allocator.destroy(v.value_ptr.*);
        }
    }
    fonts_char_info.deinit();
    {
        var iter = font_atlas_by_id.iterator();
        while (iter.next()) |v| {
            allocator.free(v.value_ptr.*);
        }
    }
    font_atlas_by_id.deinit();

    {
        var iter = font_id_by_name.keyIterator();
        while (iter.next()) |v| {
            allocator.free(v.*);
        }
    }
    font_id_by_name.deinit();

    const leaked = gpa.deinit();
    if (leaked) fm_log.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn addFont(font_name: []const u8,
               file_name: []const u8) FontError!void {
    fm_log.info("Opening file {s}", .{file_name});
    // const file = try std.fs.cwd().openFile(file_name, .{});
    const file = std.fs.cwd().openFile(file_name, .{}) catch |e| {
        fm_log.warn("{}", .{e});
        return FontError.FontLoadingFailed;
    };
    defer file.close();

    const stat = file.stat() catch |e| {
        fm_log.warn("{}", .{e});
        return FontError.FontLoadingFailed;
    };
    fm_log.debug("File size: {}", .{stat.size});

    const font_mem = file.reader().readAllAlloc(allocator, stat.size) catch |e| {
        fm_log.warn("{}", .{e});
        return FontError.FontLoadingFailed;
    };

    fonts_map.put(font_name, font_mem) catch |e|
    {
        fm_log.warn("{}", .{e});
        return FontError.FontLoadingFailed;
    };
    fm_log.info("Number of fonts: {}", .{fonts_map.count()});
}

pub fn rasterise(font_name: []const u8, font_size: f32, tex_id: u32) FontError!void {

    // Check, if font with font_name exists
    if (!fonts_map.contains(font_name)) return error.FontNameUnknown;

    // Create and store designator consisting of font_name and the size
    const font_name_sized = std.fmt.allocPrint(allocator, "{s}_{d:.0}",
                                               .{font_name, font_size}) catch |e| {
        fm_log.warn("{}", .{e});
        return error.FontRasterisingFailed;
    };
    // defer allocator.free(font_name_sized);
    fm_log.debug("Rasterising font with size {d:.0} named {s}",
                 .{font_size, font_name_sized});

    font_id_by_name.put(font_name_sized, @intCast(u32, tex_id)) catch |e| {
        fm_log.warn("{}", .{e});
        return error.FontRasterisingFailed;
    };

    // Prepare character information such as kerning
    font_current_char_info = allocator.create(c.stbtt_packedchar) catch |e| {
        fm_log.warn("{}", .{e});
        return error.FontRasterisingFailed;
    };
    fonts_char_info.put(tex_id, font_current_char_info) catch |e| {
        fm_log.warn("{}", .{e});
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
        }

        // Allocate memory for the atlas and add reference based
        // on texture id
        const atlas = allocator.alloc(u8, s) catch |e| {
            fm_log.warn("{}", .{e});
            return error.FontRasterisingFailed;
        };

        // try font_atlas_mem.append(atlas);
        font_atlas_by_id.put(tex_id, atlas) catch |e| {
            fm_log.warn("{}", .{e});
            return error.FontRasterisingFailed;
        };

        // Try to pack atlas
        atlas_done = true;
        var pack_context: c.stbtt_pack_context = undefined;
        const r0 = c.stbtt_PackBegin(&pack_context, @ptrCast([*c]u8, atlas),
                                     @intCast(c_int, font_atlas_size_default * atlas_scale),
                                     @intCast(c_int, font_atlas_size_default * atlas_scale), 0, 1, null);
        if (r0 == 0) {
            fm_log.debug("Could not pack font with texture size {}, trying larger texture size.",
                         .{font_atlas_size_default * atlas_scale});
            atlas_done = false;
        } else {
            c.stbtt_PackSetOversampling(&pack_context, 1, 1);
            const r1 = c.stbtt_PackFontRange(&pack_context, @ptrCast([*c]u8, fonts_map.get(font_name).?),
                                            0, font_size, ascii_first, ascii_nr,
                                            @ptrCast([*c]c.stbtt_packedchar, fonts_char_info.get(tex_id).?));
            if (r1 == 0) {
                fm_log.debug("Could not pack font with texture size {}, trying larger texture size.",
                            .{font_atlas_size_default * atlas_scale});
                atlas_done = false;
            }
            else {
                c.stbtt_PackEnd(&pack_context);
            }
        }
    }

    if (!atlas_done) {
        fm_log.warn("Could not pack font {s} with size {d:.0}, try to reduce font size.",
                    .{font_name, font_size});
        fm_log.warn("Texture size would have been {}",
                    .{font_atlas_size_default * (atlas_scale / 2)});
        return error.FontRasterisingFailed;
    } else {
        gfx.createTexture1C(font_atlas_size_default * @intCast(u32, atlas_scale/2),
                            font_atlas_size_default * @intCast(u32, atlas_scale/2),
                            font_atlas_by_id.get(tex_id).?, tex_id);
    }
}

pub fn renderAtlas() void {
    const tex_id = font_id_by_name.get("anka_32").?;
    gfx.setActiveTexture(tex_id);
    c.glBindTexture(c.GL_TEXTURE_2D, tex_id);

    c.glEnable(c.GL_TEXTURE_2D);

    const x0 = 100;
    const x1 = 612;
    const y0 = 100;
    const y1 = 612;
    c.glBegin(c.GL_QUADS);
        c.glTexCoord2f(0.0, 0.0); c.glVertex2f(x0, y0);
        c.glTexCoord2f(1.0, 0.0); c.glVertex2f(x1, y0);
        c.glTexCoord2f(1.0, 1.0); c.glVertex2f(x1, y1);
        c.glTexCoord2f(0.0, 1.0); c.glVertex2f(x0, y1);
    c.glEnd();
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

/// Font manager logging scope
const fm_log = std.log.scoped(.fnt);

var gpa = if (cfg.debug_allocator) std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){} else std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Number of relevant ASCII characters
const ascii_nr = 95;
const ascii_first = 32;
const font_atlas_size_default = 32;
const font_atlas_scale_max = 8;

/// Raw font information as read from file
var fonts_map = std.StringHashMap([]u8).init(allocator);

/// Font information like kerning for all rasterised fonts
var fonts_char_info = std.AutoHashMap(c_uint, *c.stbtt_packedchar).init(allocator);

/// Font information of current font
var font_current_char_info: *c.stbtt_packedchar = undefined;

/// Access atlas by given texture id
var font_atlas_by_id = std.AutoHashMap(c_uint, []u8).init(allocator);

/// Texture id of font atlas for a given font name
var font_id_by_name = std.StringHashMap(u32).init(allocator);

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "open_font_file_fail_expected" {
    const actual = addFont("non_existing_fond_name", "./this/font/does/not/exist.ttf");
    const expected = FontError.FontLoadingFailed;
    try std.testing.expectError(expected, actual);
}

test "open_font_file" {
    try addFont("anka", "resource/AnkaCoder-r.ttf");
}

test "rasterise_font" {
    try rasterise("anka", 16, 0);
}

test "rasterise_font_fail_expected" {
    const actual = rasterise("no_font_name", 16, 0);
    const expected = error.FontNameUnknown;
    try std.testing.expectError(expected, actual);
}
