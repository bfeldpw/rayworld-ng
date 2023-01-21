const std = @import("std");

pub const CellType = enum {
    floor,
    wall,
    mirror,
    glass,
};

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

pub fn get() *const[map_size_y][map_size_x]CellType {
    return &map_current.cell_type;
}

pub fn getAttributeIndex() *const[map_size_y][map_size_x]usize {
    return &map_current.i_attr;
}

pub fn getAttributesMirror() *const[map_size_y*map_size_x]MirrorAttributes {
    return &map_current.attr_mirror;
}

pub fn getAttributesWall() *const[map_size_y*map_size_x]WallAttributes {
    return &map_current.attr_wall;
}

pub fn getColor() *const[map_size_y][map_size_x]CellColor {
    return &map_current.col;
}

pub fn getResolution() u32 {
    return res;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_map = std.log.scoped(.map);

var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
// var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const res = 1; // resolution of blocks in meter
const map_size_y = 18;
const map_size_x = 20;

/// Base color of each cell
const CellColor = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

const MirrorAttributes = struct {
    col_r: f32,
    col_g: f32,
    col_b: f32,
    canvas_top: f32,
    canvas_bottom: f32,
    opacity: f32,
    opacity_canvas: f32,
};

const WallAttributes = struct {
    opacity: f32,
};

/// Struct of Arrays (SoA) for all map information, that ist cells and their
/// common attributes. Specific attributes are indexed
const Map = struct {
    cell_type: [map_size_y][map_size_x]CellType,
    col: [map_size_y][map_size_x]CellColor,
    i_attr: [map_size_y][map_size_x]usize, // Index to specific cell attributes
    attr_mirror: [map_size_y*map_size_x]MirrorAttributes, // Size should be dynamic later, therefore the index
    attr_wall: [map_size_y*map_size_x]WallAttributes, // Size should be dynamic later, therefore the index
};

/// Currently used map, later to be loaded from file
// var map_current = Map {
//     .cell_type = undefined,
//     .col = undefined,
//     .i_attr = undefined,
//     .attr_mirror = undefined,
//     .attr_wall = undefined,
// };
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
    [_]u8{1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1},
    [_]u8{1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1},
};

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
                .wall => {
                    // map_current.col[j][i].r = 1.0;
                    // map_current.col[j][i].g = 1.0;
                    // map_current.col[j][i].b = 1.0;
                    // map_current.col[j][i].a = 1.0;
                    map_current.col[j][i].r = 0.6;
                    map_current.col[j][i].g = 0.6;
                    map_current.col[j][i].b = 0.6;
                    map_current.col[j][i].a = 1.0;
                    map_current.i_attr[j][i] = 0;
                    map_current.attr_wall[0].opacity = 0.925;
                },
                .mirror => {
                    map_current.col[j][i].r = 0.6;
                    map_current.col[j][i].g = 0.6;
                    map_current.col[j][i].b = 0.6;
                    map_current.col[j][i].a = 1.0;
                    map_current.i_attr[j][i] = 0;
                    map_current.attr_mirror[0].col_r = 0.0;
                    map_current.attr_mirror[0].col_g = 0.0;
                    map_current.attr_mirror[0].col_b = 1.0;
                    map_current.attr_mirror[0].canvas_top= 0.075;
                    map_current.attr_mirror[0].canvas_bottom= 0.075;
                    map_current.attr_mirror[0].opacity = 0.1;
                    map_current.attr_mirror[0].opacity_canvas = 0.925;
                },
                .glass => {
                    map_current.col[j][i].r = 0.5;
                    map_current.col[j][i].g = 1.0;
                    map_current.col[j][i].b = 0.5;
                    map_current.col[j][i].a = 0.05;
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
    map_current.col[8][8].r = 0.6;
    map_current.col[8][8].g = 0.6;
    map_current.col[8][8].b = 0.6;
    map_current.col[8][8].a = 0.3;
    map_current.i_attr[8][8] = 1;
    map_current.attr_mirror[1].col_r = 0.0;
    map_current.attr_mirror[1].col_g = 1.0;
    map_current.attr_mirror[1].col_b = 1.0;
    map_current.attr_mirror[1].canvas_top= 0.2;
    map_current.attr_mirror[1].canvas_bottom= 0.6;
    map_current.attr_mirror[1].opacity = 0.3;
    map_current.attr_mirror[1].opacity_canvas = 0.925;
}

pub fn deinit() void {
    allocator.destroy(map_current);

    const leaked = gpa.deinit();
    if (leaked) log_map.err("Memory leaked in GeneralPurposeAllocator", .{});
}
