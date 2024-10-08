const std = @import("std");
const cfg = @import("config.zig");
const gfx_core = @import("gfx_core.zig");
const gfx_base = @import("gfx_base.zig");
const stats = @import("stats.zig");

pub var is_map_displayed: bool = false;

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {

    timing.init();

    const mass_planet = 1e26;

    // Initialise planet
    try objs.append(allocator, .{
        .acc = .{0.0, 0.0},
        .vel = .{0.0, 0.0},
        .pos = .{0.0, 0.0},
        .mass = mass_planet,
        .mass_inv = 1.0 / mass_planet,
        .radius = 5e6,
    });

    const orbit_radius = 7e6;
    // const orbit_velocity = @sqrt(gravitational_constant * mass_planet / orbit_radius);

    switch (cfg.sim.scenario) {
        .falling_station => try initFallingStation(mass_planet, orbit_radius),
        .breaking_asteriod => try initBreakingAsteriod(mass_planet, orbit_radius),
        else => {},
    }

    log_sim.debug("Number of objects: {}", .{objs.len});

    buf_id_debris = try gfx_base.addBuffer(cfg.sim.number_of_debris * 6 + 12, .PxyCrgbaF32, null); // Reserve for debris and station
    buf_id_planet = try gfx_base.addBuffer(100 * 6, .PxyCrgbaF32, null); // Reserve for debris and station
}

pub fn deinit() void {
    objs.deinit(allocator);

    const leaked = gpa.deinit();
    if (leaked == .leak) log_sim.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter / Setter
//-----------------------------------------------------------------------------//

pub inline fn getBufferIdDebris() u32 {
    return buf_id_debris;
}

pub inline fn getBufferIdPlanet() u32 {
    return buf_id_planet;
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn createScene() !void {

    if (is_map_displayed) {
        const win_w = @as(f32, @floatFromInt(gfx_core.getWindowWidth()));
        const win_h = @as(f32, @floatFromInt(gfx_core.getWindowHeight()));

        var hook: vec_2d = .{0.0, 0.0};
        const zoom_x2: vec_2d = @splat(cam.zoom);
        const win_center: vec_2d = .{win_w * 0.5, win_h * 0.5};

        if (cam.station_hook) {
            hook = objs.items(.pos)[1];
        }

        {
            const data = try gfx_base.getBufferToAddVertexData(buf_id_debris, @intCast((objs.len - 2) * 6));
            const data_p = data.ptr;
            const tmp = ( cam.p - hook ) * zoom_x2 + win_center;
            var i: usize = 2;
            while (i < objs.len) : (i += 1) {
                const p = objs.items(.pos)[i] * zoom_x2 + tmp;
                const j = (i - 2) * 6;

                data_p[j    ] = @as(f32, @floatCast(p[0]));
                data_p[j + 1] = @as(f32, @floatCast(p[1]));
                data_p[j + 2] = 0.7;
                data_p[j + 3] = 0.2;
                data_p[j + 4] = 0.0;
                data_p[j + 5] = 0.5;
            }
        }

        // The station
        const s_p = (objs.items(.pos)[1] + cam.p - hook) * zoom_x2 + win_center;

        var data = [6]f32{
            @as(f32, @floatCast(s_p[0])), @as(f32, @floatCast(s_p[1])), 1.0, 0.1, 0.0, 0.5,
        };
        try gfx_base.addVertexData(buf_id_debris, &data);

        // The planet
        const c_p = (objs.items(.pos)[0] + cam.p - hook) * zoom_x2 + win_center;
        const c_r = cam.zoom * @as(f32, @floatCast(objs.items(.radius)[0]));
        try gfx_base.addCircle(buf_id_planet, @as(f32, @floatCast(c_p[0])), @as(f32, @floatCast(c_p[1])), c_r,
                               0.7, 0.2, 0.0, 0.5);
    }
}


pub fn run() !void {
    var timer = try std.time.Timer.start();

    log_sim.info("Starting simulation", .{});

    var perf = try stats.PerFrameTimerBuffered(128).init();
    while (is_running) {
        perf.start();
        if (timing.is_paused) {
            step();
        }
        perf.stop();
        prf_avg_buf_ms = perf.getAvgBufMs();
        const t = timer.read();

        const t_step = @subWithOverflow(timing.frame_time, t);
        if (t_step[1] == 0) std.time.sleep(t_step[0])
        else timing.decreaseFpsTarget();

        timer.reset();
    }
    prf_avg_all_ms = perf.getAvgAllMs();
}

pub fn step() void {
    const dt: vec_2d = @splat(@as(f64, timing.acceleration/timing.fps_base));

    var i: usize = 1;
    while (i < objs.len) : (i += 1) {
        const d = objs.items(.pos)[0]-objs.items(.pos)[i];
        const r_sqr = @reduce(.Add, d*d); // = d[0]*d[0] + d[1]*d[1]
        const r = @sqrt(r_sqr);
        const r_x2: vec_2d = @splat(r);
        const m = objs.items(.mass)[0];
        const a = gravitational_constant * m / r_sqr;
        const a_x2: vec_2d = @splat(a);
        const e_0 = d / r_x2;
        objs.items(.acc)[i] = e_0 * a_x2;
    }
    // if (cfg.sim.scenario == .falling_station) {
        const drag: f64 = -1.0e-5;
        objs.items(.acc)[1] += @as(vec_2d, @splat(drag)) * objs.items(.vel)[1];
    // }

    i = 0;
    while (i < objs.len) : (i += 1) {
        objs.items(.vel)[i] += objs.items(.acc)[i] * dt;
        objs.items(.pos)[i] += objs.items(.vel)[i] * dt;
    }
}

pub inline fn getAvgAllMs() f64 {
    return prf_avg_all_ms;
}

pub inline fn getAvgBufMs() f64 {
    return prf_avg_buf_ms;
}

pub fn stop() void {
    log_sim.info("Simulation terminating", .{});
    @atomicStore(bool, &is_running, false, .release);
}

pub inline fn moveMapLeft() void {
    cam.p[0] += 10.0 / cam.zoom * 60.0 / gfx_core.getFPS();
}

pub inline fn moveMapRight() void {
    cam.p[0] -= 10.0 / cam.zoom * 60.0 / gfx_core.getFPS();
}

pub inline fn moveMapUp() void {
    cam.p[1] += 10.0 / cam.zoom * 60.0 / gfx_core.getFPS();
}

pub inline fn moveMapDown() void {
    cam.p[1] -= 10.0 / cam.zoom * 60.0 / gfx_core.getFPS();
}

pub inline fn toggleMap() void {
    is_map_displayed = is_map_displayed != true;
}

pub inline fn togglePause() void {
    timing.is_paused = timing.is_paused != true;
}

pub inline fn toggleStationHook() void {
    cam.station_hook = cam.station_hook != true;
}

pub inline fn zoomInMap() void {
    cam.zoom *= 1.0 + 0.1 * 60.0 / gfx_core.getFPS();
}

pub inline fn zoomOutMap() void {
    cam.zoom *= 1.0 - 0.1 * 60.0 / gfx_core.getFPS();
}

pub const timing = struct {

    pub inline fn getFpsTarget() f32 {
        return fps_target;
    }

    pub fn accelerate() void {
        if (10.0 * acceleration / fps_base <= 10.0) {
            acceleration *= 10.0;
        } else {
            log_sim.warn("Acceleration too high, keeping {d:.0} for numeric stability.", .{acceleration});
        }
        log_sim.info("Simulation rate at {d:.2}x @{d:.0}Hz", .{acceleration, fps_target});
    }

    pub fn decelerate() void {
        acceleration *= 0.1;
        log_sim.info("Simulation rate at {d:.2}x @{d:.0}Hz", .{acceleration, fps_target});
    }

    pub fn decreaseFpsTarget() void {
        if (fps_target > 100.0) {
            fps_target -= 100.0;
            frame_time = @intFromFloat(1.0/fps_target*1.0e9);
            log_sim.info("Simulation rate at {d:.2}x @{d:.0}Hz", .{acceleration, fps_target});
        }
    }

    pub fn increaseFpsTarget() void {
        fps_target += 100.0;
        frame_time = @intFromFloat(1.0/fps_target*1.0e9);
        log_sim.info("Simulation rate at {d:.2}x @{d:.0}Hz", .{acceleration, fps_target});
    }

    fn init() void {
        fps_target = cfg.sim.fps_target;
        acceleration = cfg.sim.acceleration;
        if (acceleration / fps_target > 10.0) {
            acceleration = 10.0 * fps_target;
            log_sim.warn("Acceleration too high, capping at {d:.0} for numeric stability.", .{acceleration});
        }
        log_sim.info("Simulation rate at {d:.2}x @{d:.0}Hz", .{acceleration, fps_target});
    }

    var acceleration: f32 = 1.0;
    var fps_base: f32 = 100.0;
    var fps_target: f32 = 100.0;
    var frame_time: u64 = @intFromFloat(1.0/cfg.sim.fps_target*1.0e9);
    var is_paused = false;
};

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_sim = std.log.scoped(.sim);

var gpa = if (cfg.debug_allocator)  std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){} else
                                    std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const gravitational_constant = 6.6743015e-11;

var is_running: bool = true;
var prf_avg_all_ms: f64 = 0.0;
var prf_avg_buf_ms: f64 = 0.0;
var buf_id_debris: u32 = 0;
var buf_id_planet: u32 = 0;

const Camera = struct {
    p: vec_2d,
    zoom: f32,
    station_hook: bool,
};
var cam = Camera {
    .p = .{0.0, 0.0},
    .zoom = 5.0e-5,
    .station_hook = false,
};

const vec_2d = @Vector(2, f64);

const PhysicalObject = struct {
    acc: vec_2d,
    pos: vec_2d,
    vel: vec_2d,
    mass: f64,
    mass_inv: f64,
    radius: f64,
};

/// All physically simulated objects. MultiArrayList is internally implemented
/// as a SoA (Struct of Arrays), which should be fine, here.
const Objects = std.MultiArrayList(PhysicalObject);

var objs = Objects{};

fn initFallingStation(mass_planet: f64, orbit_radius: f64) !void {
    var r_gen = std.rand.DefaultPrng.init(23);
    const prng = r_gen.random();

    const o_sr = orbit_radius + 2.0e6;
    const o_sv = @sqrt(gravitational_constant * mass_planet / o_sr);
    var i: u32 = 0;
    // Initialise station
    try objs.append(allocator, .{
        .acc = .{0.0, 0.0},
        .vel = .{0.0, o_sv},
        .pos = .{o_sr, 0.0},
        .mass = 500e3, // ISS-like ~ 500t
        .mass_inv = 1.0 / 500e3,
        .radius = 50, // ISS-like ~94m x 73m
    });

    i = 0;
    while (i < cfg.sim.number_of_debris) : (i += 1) {

        const o_std = prng.floatNorm(f64) * 350.0e3;
        const ang_std = prng.floatNorm(f64) * 0.1;
        const o_r = orbit_radius + o_std;
        const ang = prng.float(f64) * 2.0 * std.math.pi;

        const o_v = @sqrt(gravitational_constant * mass_planet / o_r);

        // Initialise debris
        try objs.append(allocator, .{
            .acc = .{0.0, 0.0},
            .vel = .{-o_v * @cos(ang+ang_std), o_v * @sin(ang+ang_std)},
            .pos = .{o_r * @sin(ang+ang_std), o_r * @cos(ang+ang_std)},
            .mass = 20e3,
            .mass_inv = 1.0 / 20e3,
            .radius = 5,
        });
    }
}

fn initBreakingAsteriod(mass_planet: f64, orbit_radius: f64) !void {
    var r_gen = std.Random.DefaultPrng.init(23);
    const prng = r_gen.random();

    const o_sr = orbit_radius + 1.0e6;
    const o_sv = @sqrt(gravitational_constant * mass_planet / o_sr);
    var i: u32 = 0;
    // Initialise station
    try objs.append(allocator, .{
        .acc = .{0.0, 0.0},
        .vel = .{0.0, o_sv},
        .pos = .{-o_sr, 0.0},
        .mass = 500e3, // ISS-like ~ 500t
        .mass_inv = 1.0 / 500e3,
        .radius = 50, // ISS-like ~94m x 73m
    });

    const o_dr = orbit_radius;
    const o_dv = @sqrt(gravitational_constant * mass_planet / o_dr);
    i = 0;
    while (i < cfg.sim.number_of_debris) : (i += 1) {

        const o_std = prng.floatNorm(f64) * 50.0e3;
        const o_r = orbit_radius + o_std;

        // const o_v = @sqrt(gravitational_constant * mass_planet / o_r);

        // Initialise debris
        try objs.append(allocator, .{
            .acc = .{0.0, 0.0},
            .vel = .{0.0, o_dv+prng.floatNorm(f64) * 1.0e2},
            .pos = .{o_r, prng.floatNorm(f64) * 25.0e3},
            .mass = 20e3,
            .mass_inv = 1.0 / 20e3,
            .radius = 5,
        });
    }
}
