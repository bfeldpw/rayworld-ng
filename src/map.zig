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

    try fillMap();
    try loadResources();
}

pub fn deinit() void {
    allocator.destroy(map_current);
    attribute_components.canvas.deinit();
    attribute_components.color.deinit();
    attribute_components.glass.deinit();
    attribute_components.texture.deinit();

    const leaked = gpa.deinit();
    if (leaked) log_map.err("Memory leaked in GeneralPurposeAllocator", .{});
}
//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub inline fn get() *const[map_size_y][map_size_x]CellType {
    return &map_current.cell_type;
}

pub inline fn getCanvas(y: usize, x: usize) *AttribCanvas {
    return &attribute_components.canvas.items[map_current.i_canvas[y][x]];
}

pub inline fn getColor(y: usize, x: usize) *AttribColor {
    return &attribute_components.color.items[map_current.i_color[y][x]];
}

pub inline fn getGlass(y: usize, x: usize) *AttribGlass {
    return &attribute_components.glass.items[map_current.i_glass[y][x]];
}

pub inline fn getTextureID(y: usize, x: usize) *AttribTexture {
    return &attribute_components.texture.items[map_current.i_texture[y][x]];
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

const AttribCanvas = struct {
    top: f32,
    bottom: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const AttribColor = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32, // i.e. alpha channel
};

const AttribGlass = struct {
    n: f32 = 1.46, // material index
};

const AttribTexture = struct {
    id: u32,
};

const AttributeComponents = struct {
    canvas: std.ArrayList(AttribCanvas),
    color: std.ArrayList(AttribColor),
    glass: std.ArrayList(AttribGlass),
    texture: std.ArrayList(AttribTexture),
};

var attribute_components = AttributeComponents {
    .canvas = std.ArrayList(AttribCanvas).init(allocator),
    .color = std.ArrayList(AttribColor).init(allocator),
    .glass = std.ArrayList(AttribGlass).init(allocator),
    .texture = std.ArrayList(AttribTexture).init(allocator),
};

/// Struct of Arrays (SoA) for all map information, that ist cells and their
/// common attributes. Specific attributes are indexed
const Map = struct {
    cell_type:  [map_size_y][map_size_x]CellType,
    i_canvas:   [map_size_y][map_size_x]usize,
    i_color:    [map_size_y][map_size_x]usize,
    i_glass:    [map_size_y][map_size_x]usize,
    i_texture:  [map_size_y][map_size_x]usize,
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

fn fillMap() !void {
    // Attributes
    // Default attributes color
    // -- floor
    try attribute_components.color.append(.{.r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0});
    // -- wall, pillar
    try attribute_components.color.append(.{.r = 1.0, .g = 1.0, .b = 1.0, .a = 0.9});
    // -- mirror
    try attribute_components.color.append(.{.r = 0.0, .g = 0.0, .b = 0.8, .a = 0.02});
    // -- glass
    try attribute_components.color.append(.{.r = 0.2, .g = 0.8, .b = 0.2, .a = 0.15});

    // Default attributes canvas
    // -- miror
    try attribute_components.canvas.append(.{.top = 0.075,
                                             .bottom = 0.075,
                                             .r = 1.0,
                                             .g = 1.0,
                                             .b = 1.0,
                                             .a = 0.9});
    // -- glass
    try attribute_components.canvas.append(.{.top = 0.0,
                                             .bottom = 0.0,
                                             .r = 1.0,
                                             .g = 1.0,
                                             .b = 1.0,
                                             .a = 1.0});

    // Default attributes glass
    try attribute_components.glass.append(.{.n = 1.46});
    try attribute_components.glass.append(.{.n = 2.49});

    // Default attributes texture
    try attribute_components.texture.append(.{.id = 0});
    try attribute_components.texture.append(.{.id = 0});

    // Copy tmp map and set some default values for celltypes
    for (map_current.cell_type) |*row, j| {
        for (row.*) |*value, i| {
            value.* = @intToEnum(CellType, map_celltype_tmp[j][i]);

            switch (value.*) {
                .floor => {
                    map_current.i_canvas[j][i] = 0;
                    map_current.i_color[j][i] = 0;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_texture[j][i] = 0;
                },
                .wall, .pillar  => {
                    map_current.i_canvas[j][i] = 0;
                    map_current.i_color[j][i] = 1;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_texture[j][i] = 0;
                },
                .mirror => {
                    map_current.i_canvas[j][i] = 0;
                    map_current.i_color[j][i] = 2;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_texture[j][i] = 0;
                },
                .glass => {
                    map_current.i_canvas[j][i] = 1;
                    map_current.i_color[j][i] = 3;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_texture[j][i] = 1;
                },
            }
        }
    }
    map_current.i_glass[22][4] = 1;
}

fn loadResources() !void {
    img.init();
    defer img.deinit();

    {
        const image = try img.loadImage("resource/metal_01_1024x2048_bfeld.jpg");
        const tex = try gfx.createTexture(image.width, image.height, &image.data);
        attribute_components.texture.items[0].id = tex;
        log_map.debug("Creating wall attribute with texture ID={}", .{tex});
        img.releaseImage();
    }
    {
        const image = try img.loadImage("resource/metal_01-1_1024x2048_bfeld.jpg");
        const tex = try gfx.createTexture(image.width, image.height, &image.data);
        attribute_components.texture.items[1].id = tex;
        log_map.debug("Creating wall attribute with texture ID={}", .{tex});
        img.releaseImage();
    }
}
