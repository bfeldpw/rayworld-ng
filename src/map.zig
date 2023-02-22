const std = @import("std");
const cfg = @import("config.zig");
const gfx = @import("graphics.zig");
const img = @import("image_loader.zig");

pub const CellType = enum {
    floor,
    wall,
    mirror,
    glass,
    pillar,
    wall_thin,
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
    attribute_components.pillar.deinit();
    attribute_components.reflection.deinit();
    attribute_components.texture.deinit();
    attribute_components.wall_thin.deinit();

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

pub inline fn getPillar(y: usize, x: usize) *AttribPillar {
    return &attribute_components.pillar.items[map_current.i_pillar[y][x]];
}

pub inline fn getReflection(y: usize, x: usize) *AttribReflection {
    return &attribute_components.reflection.items[map_current.i_reflection[y][x]];
}

pub inline fn getTextureID(y: usize, x: usize) *AttribTexture {
    return &attribute_components.texture.items[map_current.i_texture[y][x]];
}

pub inline fn getWallThin(y: usize, x: usize) *AttribWallThin {
    return &attribute_components.wall_thin.items[map_current.i_wall[y][x]];
}

pub inline fn getResolution() u32 {
    return res;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_map = std.log.scoped(.map);

var gpa = if (cfg.debug_allocator)  std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){} else
                                    std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const res = 1; // resolution of blocks in meter
const map_size_y = 40;
const map_size_x = 30;

const WallAxis = enum {
    x,
    y,
};

const AttribCanvas = struct {
    top: f32,
    bottom: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    tex_id: u32,
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

const AttribPillar = struct {
    radius: f32 = 0.3,
    center_x: f32 = 0.5,
    center_y: f32 = 0.5,
};

const AttribReflection = struct {
    limit: i8,
    diffusion: f32,
    sub_sampling: f32,
};

const AttribTexture = struct {
    id: u32,
};

const AttribWallThin = struct {
    axis: WallAxis,
    from: f32,
    to: f32,
};

const AttributeComponents = struct {
    canvas: std.ArrayList(AttribCanvas),
    color:  std.ArrayList(AttribColor),
    glass:  std.ArrayList(AttribGlass),
    pillar:  std.ArrayList(AttribPillar),
    reflection: std.ArrayList(AttribReflection),
    texture: std.ArrayList(AttribTexture),
    wall_thin: std.ArrayList(AttribWallThin),
};

var attribute_components = AttributeComponents {
    .canvas = std.ArrayList(AttribCanvas).init(allocator),
    .color = std.ArrayList(AttribColor).init(allocator),
    .glass = std.ArrayList(AttribGlass).init(allocator),
    .pillar = std.ArrayList(AttribPillar).init(allocator),
    .reflection = std.ArrayList(AttribReflection).init(allocator),
    .texture = std.ArrayList(AttribTexture).init(allocator),
    .wall_thin = std.ArrayList(AttribWallThin).init(allocator),
};

/// Struct of Arrays (SoA) for all map information, that ist cells and their
/// common attributes. Specific attributes are indexed
const Map = struct {
    cell_type:  [map_size_y][map_size_x]CellType,
    i_canvas:   [map_size_y][map_size_x]usize,
    i_color:    [map_size_y][map_size_x]usize,
    i_glass:    [map_size_y][map_size_x]usize,
    i_pillar:   [map_size_y][map_size_x]usize,
    i_reflection: [map_size_y][map_size_x]usize,
    i_texture:  [map_size_y][map_size_x]usize,
    i_wall:     [map_size_y][map_size_x]usize,
};

/// Currently used map, later to be loaded from file
var map_current: *Map = undefined;

/// Temporary celltypes for convenience as long as maps are hardcoded here.
/// This map will be copied over to that currently used in the init function.
const map_celltype_tmp = [map_size_y][map_size_x]u8 {
    [_]u8{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 1, 1, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 1, 0, 0, 0, 4, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 2, 2, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 0, 0, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 0, 0, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 2, 0, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 0, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 2, 0, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 0, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 2, 2, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 0, 2, 1, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 3, 0, 4, 0, 0, 4, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
};

fn fillMap() !void {
    // Attributes
    // Default attributes color
    // -- floor
    try attribute_components.color.append(.{.r = 0.2, .g = 0.2, .b = 0.2, .a = 1.0});
    // -- wall, pillar
    try attribute_components.color.append(.{.r = 1.0, .g = 1.0, .b = 1.0, .a = 0.9});
    // -- mirror
    try attribute_components.color.append(.{.r = 0.0, .g = 0.0, .b = 0.5, .a = 0.2});
    // -- glass
    try attribute_components.color.append(.{.r = 0.2, .g = 0.8, .b = 0.2, .a = 0.05});

    // Default attributes canvas
    // -- miror
    try attribute_components.canvas.append(.{.top = 0.075,
                                             .bottom = 0.075,
                                             .r = 1.0,
                                             .g = 1.0,
                                             .b = 1.0,
                                             .a = 0.9,
                                             .tex_id = 1});
    // -- glass
    try attribute_components.canvas.append(.{.top = 0.0,
                                             .bottom = 0.0,
                                             .r = 1.0,
                                             .g = 1.0,
                                             .b = 1.0,
                                             .a = 1.0,
                                             .tex_id = 1});

    // Default attributes glass
    try attribute_components.glass.append(.{.n = 1.46});
    try attribute_components.glass.append(.{.n = 1.20});

    // Default attributes pillar
    try attribute_components.pillar.append(.{.radius = 0.1, .center_x = 0.5, .center_y = 0.8});
    try attribute_components.pillar.append(.{.radius = 0.3, .center_x = 0.5, .center_y = 0.5});
    try attribute_components.pillar.append(.{.radius = 0.5, .center_x = 0.5, .center_y = 0.5});

    // Default attributes reflection
    // -- wall
    try attribute_components.reflection.append(.{.limit = 3, .diffusion = 0.0, .sub_sampling = 2});
    // -- floor, mirror, glass, pillar (as mirror)
    try attribute_components.reflection.append(.{.limit = cfg.rc.segments_max, .diffusion = 0.0, .sub_sampling = 1});


    // Default attributes texture
    try attribute_components.texture.append(.{.id = 0});
    try attribute_components.texture.append(.{.id = 0});
    try attribute_components.texture.append(.{.id = 0});
    try attribute_components.texture.append(.{.id = 0});

    // Default attributes wall_thin
    try attribute_components.wall_thin.append(.{.axis = .x, .from = 0.4, .to = 0.6});

    // Copy tmp map and set some default values for celltypes
    for (map_current.cell_type) |*row, j| {
        for (row.*) |*value, i| {
            value.* = @intToEnum(CellType, map_celltype_tmp[j][i]);

            map_current.i_pillar[j][i] = 1;
            switch (value.*) {
                .floor => {
                    map_current.i_canvas[j][i] = 1;
                    map_current.i_color[j][i] = 0;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_reflection[j][i] = 1;
                    map_current.i_texture[j][i] = 0;
                    map_current.i_wall[j][i] = 0;
                },
                .wall, .wall_thin => {
                    map_current.i_canvas[j][i] = 1;
                    map_current.i_color[j][i] = 1;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_reflection[j][i] = 0;
                    map_current.i_texture[j][i] = 1;
                    map_current.i_wall[j][i] = 0;
                },
                .mirror => {
                    map_current.i_canvas[j][i] = 0;
                    map_current.i_color[j][i] = 2;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_reflection[j][i] = 1;
                    map_current.i_texture[j][i] = 0;
                    map_current.i_wall[j][i] = 0;
                },
                .glass => {
                    map_current.i_canvas[j][i] = 1;
                    map_current.i_color[j][i] = 3;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_reflection[j][i] = 1;
                    map_current.i_texture[j][i] = 1;
                    map_current.i_wall[j][i] = 0;
                },
                .pillar  => {
                    map_current.i_canvas[j][i] = 1;
                    map_current.i_color[j][i] = 1;
                    map_current.i_glass[j][i] = 0;
                    map_current.i_reflection[j][i] = 0;
                    map_current.i_texture[j][i] = 1;
                    map_current.i_wall[j][i] = 0;
                },
            }
        }
    }
    map_current.i_glass[22][4] = 1;
    map_current.i_texture[6][10] = 3;
    map_current.i_canvas[11][7] = 0;
    map_current.i_color[11][7] = 2;
    map_current.i_pillar[11][7] = 2;
    map_current.i_reflection[11][7] = 1;
    map_current.i_pillar[18][6] = 0;
    map_current.i_pillar[18][9] = 0;
}

fn loadResources() !void {
    img.init();
    defer img.deinit();

    {
        const image = try img.loadImage("resource/metal_01_1024x2048_bfeld.jpg");
        const tex = try gfx.createTexture(image.width, image.height, &image.data);
        attribute_components.texture.items[1].id = tex;
        log_map.debug("Creating texture attribute with texture ID={}", .{tex});
        img.releaseImage();
    }
    {
        const image = try img.loadImage("resource/metal_01-1_1024x2048_bfeld.jpg");
        const tex = try gfx.createTexture(image.width, image.height, &image.data);
        attribute_components.texture.items[2].id = tex;
        log_map.debug("Creating texture attribute with texture ID={}", .{tex});
        img.releaseImage();
    }
    {
        const image = try img.loadImage("resource/metal_01-2_1024x2048_bfeld.jpg");
        const tex = try gfx.createTexture(image.width, image.height, &image.data);
        attribute_components.texture.items[3].id = tex;
        log_map.debug("Creating texture attribute with texture ID={}", .{tex});
        img.releaseImage();
    }
}
