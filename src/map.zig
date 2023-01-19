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

/// Struct of Arrays (SoA) for all map information, that ist cells and their
/// common attributes. Specific attributes are indexed
const Map = struct {
    cell_type: [map_size_y][map_size_x]CellType,
    col: [map_size_y][map_size_x]CellColor,
};

/// Currently used map, later to be loaded from file
var map_current = Map {
    .cell_type = undefined,
    .col = undefined,
};

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
pub fn init() void {
    log_map.info("Initialising map", .{});

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
                    map_current.col[j][i].r = 1.0;
                    map_current.col[j][i].g = 1.0;
                    map_current.col[j][i].b = 1.0;
                    map_current.col[j][i].a = 1.0;
                },
                .mirror => {
                    map_current.col[j][i].r = 0.5;
                    map_current.col[j][i].g = 0.5;
                    map_current.col[j][i].b = 1.0;
                    map_current.col[j][i].a = 0.1;
                },
                .glass => {
                    map_current.col[j][i].r = 0.5;
                    map_current.col[j][i].g = 1.0;
                    map_current.col[j][i].b = 0.5;
                    map_current.col[j][i].a = 0.5;
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
    map_current.col[8][8].b = 0.0;
    map_current.col[8][8].a = 0.3;
}
