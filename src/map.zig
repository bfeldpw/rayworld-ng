const std = @import("std");
const gfx = @import("graphics.zig");
const img = @import("image_loader.zig");

pub const CellType = enum {
    floor,
    wall,
    mirror,
    glass,
    pillar,
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

/// This function initialises the map by copying and setting attributes as
/// long as maps are hardcoded here. Later, map data should be loaded from
/// file.
pub fn init() !void {
    log_map.info("Initialising map", .{});

    map_current = allocator.create(Map) catch |e| {
        log_map.err("Allocation error: {}", .{e});
        return e;
    };
    errdefer allocator.destroy(map_current);

    // Attributes
    // Default attributes color
    // -- mirror
    map_current.attr_color[0].col_r = 0.0;
    map_current.attr_color[0].col_g = 0.0;
    map_current.attr_color[0].col_b = 0.8;
    map_current.attr_color[0].opacity = 0.02;
    // -- glass
    map_current.attr_color[1].col_r = 0.2;
    map_current.attr_color[1].col_g = 0.8;
    map_current.attr_color[1].col_b = 0.2;
    map_current.attr_color[1].opacity = 0.05;

    // Default attributes canvas
    // -- miror
    map_current.attr_canvas[0].canvas_top = 0.075;
    map_current.attr_canvas[0].canvas_bottom = 0.075;
    map_current.attr_canvas[0].canvas_opacity = 0.9;
    // -- glass
    map_current.attr_canvas[1].canvas_top = 0.0;
    map_current.attr_canvas[1].canvas_bottom = 0.0;
    map_current.attr_canvas[1].canvas_opacity = 1.0;

    // Default attributes wall
    map_current.attr_wall[0].opacity = 0.9;
    map_current.attr_wall[0].tex_id = 0;
    map_current.attr_wall[1].opacity = 0.9;
    map_current.attr_wall[1].tex_id = 0;

    // Copy tmp map and set some default values for celltypes
    for (map_current.cell_type) |*row, j| {
        for (row.*) |*value, i| {
            value.* = @intToEnum(CellType, map_celltype_tmp[j][i]);

            switch (value.*) {
                .floor => {
                    map_current.col[j][i].r = 0.2;
                    map_current.col[j][i].g = 0.2;
                    map_current.col[j][i].b = 0.2;
                    map_current.col[j][i].a = 1.0;
                },
                .wall  => {
                    map_current.col[j][i].r = 1.0;
                    map_current.col[j][i].g = 1.0;
                    map_current.col[j][i].b = 1.0;
                    map_current.col[j][i].a = 1.0;
                    map_current.i_attr[j][i] = 0;
                },
                .mirror => {
                    map_current.col[j][i].r = 1.0;
                    map_current.col[j][i].g = 1.0;
                    map_current.col[j][i].b = 1.0;
                    map_current.col[j][i].a = 1.0;
                    map_current.i_attr[j][i] = 0;
                    map_current.i_attr_color[j][i] = 0;
                    map_current.i_attr_canvas[j][i] = 0;
                },
                .glass => {
                    map_current.col[j][i].r = 1.0;
                    map_current.col[j][i].g = 1.0;
                    map_current.col[j][i].b = 1.0;
                    map_current.col[j][i].a = 1.0;
                    map_current.i_attr[j][i] = 0;
                    map_current.i_attr_color[j][i] = 1;
                    map_current.i_attr_canvas[j][i] = 1;
                },
                .pillar  => {
                    map_current.col[j][i].r = 1.0;
                    map_current.col[j][i].g = 1.0;
                    map_current.col[j][i].b = 1.0;
                    map_current.col[j][i].a = 1.0;
                    map_current.i_attr[j][i] = 0;
                },
            }
        }
    }
    map_current.col[0][3].r = 0.7;
    map_current.col[0][3].g = 1.0;
    map_current.col[0][3].b = 0.7;
    map_current.col[0][3].a = 1.0;
    map_current.col[0][4].r = 0.8;
    map_current.col[0][4].g = 1.0;
    map_current.col[0][4].b = 0.8;
    map_current.col[0][4].a = 1.0;
    map_current.col[0][5].r = 0.9;
    map_current.col[0][5].g = 1.0;
    map_current.col[0][5].b = 0.9;
    map_current.col[0][5].a = 1.0;
    map_current.col[8][8].r = 1.0;
    map_current.col[8][8].g = 1.0;
    map_current.col[8][8].b = 1.0;
    map_current.col[8][8].a = 1.0;
    map_current.i_attr_color[8][8] = 2;
    map_current.attr_color[2].col_r = 0.0;
    map_current.attr_color[2].col_g = 0.8;
    map_current.attr_color[2].col_b = 0.8;
    map_current.attr_color[2].opacity = 0.02;
    map_current.i_attr_canvas[8][8] = 2;
    map_current.attr_canvas[2].canvas_top = 0.2;
    map_current.attr_canvas[2].canvas_bottom = 0.6;
    map_current.attr_canvas[2].canvas_opacity = 0.9;

    map_current.i_attr[5][0] = 1;
    map_current.i_attr[17][10] = 1;

    try loadResources();
}

pub fn deinit() void {
    allocator.destroy(map_current);

    const leaked = gpa.deinit();
    if (leaked) log_map.err("Memory leaked in GeneralPurposeAllocator", .{});
}
//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn get() *const[map_size_y][map_size_x]CellType {
    return &map_current.cell_type;
}

pub inline fn getAttributeIndex() *const[map_size_y][map_size_x]usize {
    return &map_current.i_attr;
}

pub inline fn getAttributeCanvasIndex() *const[map_size_y][map_size_x]usize {
    return &map_current.i_attr_canvas;
}

pub inline fn getAttributeColorIndex() *const[map_size_y][map_size_x]usize {
    return &map_current.i_attr_color;
}

pub inline fn getAttributesCanvas(index: usize) *const AttribCanvas {
    return &map_current.attr_canvas[index];
}

pub inline fn getAttributesColor(index: usize) *const AttribColor {
    return &map_current.attr_color[index];
}

pub inline fn getAttributesWall() *const[map_size_y*map_size_x]WallAttributes {
    return &map_current.attr_wall;
}

pub inline fn getColor() *const[map_size_y][map_size_x]CellColor {
    return &map_current.col;
}

pub inline fn getResolution() u32 {
    return res;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_map = std.log.scoped(.map);

// var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const res = 1; // resolution of blocks in meter
const map_size_y = 40;
const map_size_x = 20;

/// Base color of each cell. This also applies to a canvas
/// of a mirror or glass
const CellColor = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const AttribCanvas = struct {
    canvas_top: f32,
    canvas_bottom: f32,
    canvas_opacity: f32,
};

const AttribColor = struct {
    col_r: f32,
    col_g: f32,
    col_b: f32,
    opacity: f32, // i.e. alpha channel
};

const WallAttributes = struct {
    opacity: f32,
    tex_id: u32,
};

/// Struct of Arrays (SoA) for all map information, that ist cells and their
/// common attributes. Specific attributes are indexed
const Map = struct {
    cell_type: [map_size_y][map_size_x]CellType,
    col: [map_size_y][map_size_x]CellColor,
    i_attr: [map_size_y][map_size_x]usize, // Index to specific cell attributes
    i_attr_canvas: [map_size_y][map_size_x]usize,
    i_attr_color: [map_size_y][map_size_x]usize,
    attr_canvas: [map_size_y*map_size_x]AttribCanvas,
    attr_color: [map_size_y*map_size_x]AttribColor,
    attr_wall: [map_size_y*map_size_x]WallAttributes, // Size should be dynamic later, therefore the index
};

/// Currently used map, later to be loaded from file
var map_current: *Map = undefined;

/// Temporary celltypes for convenience as long as maps are hardcoded here.
/// This map will be copied over to that currently used in the init function.
const map_celltype_tmp = [map_size_y][map_size_x]u8 {
    [_]u8{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 1, 1, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
};

fn loadResources() !void {
    img.init();
    defer img.deinit();

    {
        const image = try img.loadImage("resource/metal_01_1024x2048_bfeld.jpg");
        const tex = try gfx.createTexture(image.width, image.height, &image.data);
        map_current.attr_wall[0].tex_id = tex;
        log_map.debug("Creating wall attribute with texture ID={}", .{tex});
        img.releaseImage();
    }
    {
        const image = try img.loadImage("resource/metal_01-1_1024x2048_bfeld.jpg");
        const tex = try gfx.createTexture(image.width, image.height, &image.data);
        map_current.attr_wall[1].tex_id = tex;
        log_map.debug("Creating wall attribute with texture ID={}", .{tex});
        img.releaseImage();
    }
}
