/// Globally enable/disable multithreading. Disabling
/// is mostly used for debugging, frequency targets
/// might not be met
pub const multithreading = true;
/// Globally turn on the General Purpose Allocators (GPAs)
/// verbose output
pub const debug_allocator = false;

pub var sub_sampling_base: u32 = 3;
pub const sub_sampling_blocky = false;

pub const sub = struct {
    /// Enables auto-subsampling. Based on raycasting and
    /// render time, the number of rays will be reduced in
    /// case of high load
    pub const auto = false;
    /// Upper threshold in [ms] for raycasting and rendering
    /// If exceeded, number of rays will be reduced
    pub const th_high = 6.0;
    /// Lower threshold in [ms] for raycasting and rendering
    /// If below, number of rays will be increased
    pub const th_low = 5.0;
    /// Maximum subsampling (minimum number of rays). Only
    /// every n-th ray will be casted
    pub const max = 50;
    /// Minimum subsampling (maximum number of rays). Every
    /// n-th ray will be casted
    pub const min = 2;
    /// Number of frames for averaging, to avoid noisy
    /// changes in the number of rays
    pub const fps_damping = 20;
};

pub const fnt = struct {
    /// Rasterise a loaded font if requested size
    /// is not yet rasterised
    pub const auto_rasterise = true;
    /// Automatically remove least used fonts if new
    /// fonts are rasterised and font_atlas_limit is
    /// reached
    pub const auto_remove = true;
    /// If auto_remove is enabled, remove only if idle time
    /// of least used font is above this limit, otherwise
    /// throw error. This is to handle situations, where
    /// all fonts are used in each frame, but the one drawn
    /// first is idling for the longest time and hence,
    /// would be removed.
    pub const auto_remove_idle_time = 1; // seconds
    /// Number of font atlasses to be kept in parallel
    pub const font_atlas_limit = 8;
};

pub const gfx = struct {
    pub const shader_dir = "./resource/shader/";

    pub const depth_levels_max = 16;
    pub const fps_target = 60; // Hz
    pub const scale_by = ScalePreference.room_height;
    pub const ambient_normal_shading = 0.1; // interval [0, 1]

    pub const scene_fbo_size_x_max = 8192;
    pub const scene_fbo_size_y_max = 4096;
    pub const scene_sampling_factor = 1.5; // maximum: 2.0

    pub var room_height: f32 = 2.0; // meter
    pub var player_fov: f32 = 90; // degrees

    const ScalePreference = enum {
        room_height,
        player_fov,
    };
};

pub const map = struct {
    pub const texture_dir = "./resource/";
    pub const fb_w = 1024;
    pub const fb_h = 2048;
};

pub const rc = struct {
    pub const map_display_every_nth_line = 1;
    pub const map_display_height = 1.0;
    pub const map_display_opacity = 0.8;
    pub const map_display_reflections_max = gfx.depth_levels_max - 1;
    pub const segments_max = gfx.depth_levels_max - 1;
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
