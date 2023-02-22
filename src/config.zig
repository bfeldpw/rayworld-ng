pub const multithreading = true;
pub const debug_allocator = false;
pub const sub_sampling_base = 2;

pub const gfx = struct {
    pub const depth_levels_max = 16;
    pub const fps_target = 60; // Hz
    pub const scale_by = ScalePreference.room_height;
    pub var room_height: f32 = 2.0; // meter
    pub var player_fov: f32 = 90; // degrees

    const ScalePreference = enum {
        room_height,
        player_fov,
    };
};

pub const rc = struct {
    pub const map_display_every_nth_line = 4;
    pub const map_display_height = 0.3;
    pub const map_display_opacity = 0.5;
    pub const map_display_reflections_max = 2;
    pub const segments_max = 10;
    pub const segments_splits_max = 2;
    pub const threads_max = 16;
};
