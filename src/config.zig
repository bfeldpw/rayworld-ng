/// Globally enable/disable multithreading. Disabling
/// is mostly used for debugging, frequency targets
/// might not be met
pub const multithreading = true;
pub const debug_allocator = false;
pub const sub_sampling_base = 4;
pub const sub_sampling_blocky = false;

pub const fnt = struct {
    /// Rasterise a loaded font if requested size
    /// is not yet rasterised
    pub const auto_rasterise = false;
    /// Number of font atlasses to be kept in parallel
    pub const font_atlas_limit = 10;
};

pub const gfx = struct {
    pub const depth_levels_max = 8;
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
    pub const segments_max = gfx.depth_levels_max-1;
    pub const segments_splits_max = 2;
    pub const threads_max = 16;
};

pub const sim = struct {
    /// Default simulation acceleration, should be no more than 10x fps_target
    /// in order to ensure stability
    pub const acceleration = 100.0;
    pub const fps_target = 100.0;
    pub const number_of_debris = 10000.0;
    pub const scenario = .breaking_asteriod;
};

const SimScenario = enum {
    falling_station,
    breaking_asteriod,
};
