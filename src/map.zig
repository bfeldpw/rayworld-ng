pub fn get() [5][5]u8 {
    return map;
}

const res = 1; // resolution of blocks in meter

// Examplary 5m*5m map
const map = [5][5]u8 {
    [_]u8{1, 1, 1, 1, 1},
    [_]u8{1, 0, 1, 0, 1},
    [_]u8{1, 0, 0, 0, 1},
    [_]u8{1, 0, 1, 0, 1},
    [_]u8{1, 1, 1, 1, 1},
};
