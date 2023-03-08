const std = @import("std");
const cfg = @import("config.zig");
const gfx = @import("graphics.zig");
const stats = @import("stats.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {

    const mass_planet = 6e24;

    var r_gen = std.rand.DefaultPrng.init(23);
    const prng = r_gen.random();

    // Initialise planet
    try objs.append(allocator, .{
        .acc = .{0.0, 0.0},
        .vel = .{0.0, 0.0},
        .pos = .{0.0, 0.0},
        .mass = mass_planet,
        .mass_inv = 1.0 / mass_planet,
        .radius = 6.371e6, // earth-like
    });

    const orbit_radius = 7e6;
    const orbit_velocity= @sqrt(gravitational_constant * mass_planet / orbit_radius);

    log_sim.debug("Orbit velocity = {} m/s", .{orbit_velocity});

    var i: u32 = 0;
    // Initialise station
    try objs.append(allocator, .{
        .acc = .{0.0, 0.0},
        .vel = .{0.0, orbit_velocity},
        .pos = .{orbit_radius, 0.0},
        .mass = 500e3, // ISS-like ~ 500t
        .mass_inv = 1.0 / 500e3,
        .radius = 50, // ISS-like ~94m x 73m
    });

    i = 0;
    while (i < cfg.sim.number_of_debris) : (i += 1) {

        const o_std = prng.floatNorm(f64) * 100.0e3;
        const v_std = prng.floatNorm(f64) * 100.0;
        const ang_std = prng.floatNorm(f64) * 0.1;
        const o_r = orbit_radius + o_std;
        const o_v = orbit_velocity + v_std;
        const ang = prng.float(f64) * 2.0 * std.math.pi;

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
    log_sim.debug("Number of objects: {}", .{objs.len});
}

pub fn deinit() void {
    objs.deinit(allocator);

    const leaked = gpa.deinit();
    if (leaked) log_sim.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn createScene() void {

    if (is_map_displayed) {
        const win_w = @intToFloat(f32, gfx.getWindowWidth());
        const win_h = @intToFloat(f32, gfx.getWindowHeight());

        gfx.setViewport(@floatToInt(u64, win_w * 0.05), @floatToInt(u64, win_h * 0.05),
                        @floatToInt(u64, win_w * 0.9), @floatToInt(u64, win_h * 0.9));
        gfx.startBatchQuads();

        gfx.setColor4(1.0, 0.5, 0.0, 0.3);
        gfx.addQuad(0, 0 ,win_w , win_h);
        gfx.setColor4(1.0, 0.5, 0.0, 0.8);

        const x0 = (@floatCast(f32, objs.items(.pos)[0][0] + cam.x) * cam.zoom) + win_w * 0.5;
        const y0 = (@floatCast(f32, objs.items(.pos)[0][1] + cam.y) * cam.zoom) + win_h * 0.5;

        const o0 = 0.1 * cam.zoom * @floatCast(f32, objs.items(.radius)[0]);
        gfx.addQuad(x0-o0, y0-o0, x0+o0, y0+o0);

        var i: usize = 1;
        while (i < objs.len) : (i += 1) {
            const o = @max(0.1 * @floatCast(f32, objs.items(.radius)[i]), 2.0);
            const x = (@floatCast(f32, objs.items(.pos)[i][0] + cam.x) * cam.zoom) + win_w * 0.5;
            const y = (@floatCast(f32, objs.items(.pos)[i][1] + cam.y) * cam.zoom) + win_h * 0.5;

            gfx.addQuad(x-o, y-o, x+o, y+o);
        }

        gfx.endBatch();
        gfx.setViewportFull();
    }
}

pub fn run() !void {
    var timer = try std.time.Timer.start();

    log_sim.info("Starting simulation", .{});

    var perf = try stats.Performance.init("Sim");
    while (is_running) {
        perf.startMeasurement();
        step();
        perf.stopMeasurement();

        const t = timer.read();

        const t_step = @subWithOverflow(frame_time, t);
        if (t_step[1] == 0) std.time.sleep(t_step[0]);

        timer.reset();
    }
    perf.printStats();
}

pub fn step() void {
    const dt = @splat(2, @as(f64, cfg.sim.acceleration/cfg.sim.fps_target));

    var i: usize = 1;
    while (i < objs.len) : (i += 1) {
        const d = objs.items(.pos)[0]-objs.items(.pos)[i];
        const r_sqr = @reduce(.Add, d*d); // = d[0]*d[0] + d[1]*d[1]
        const r = @sqrt(r_sqr);
        const r_x2 = @splat(2, r);
        const m = objs.items(.mass)[0];
        const a = gravitational_constant * m / r_sqr;
        const a_x2 = @splat(2, a);
        const e_0 = d / r_x2;
        objs.items(.acc)[i] = e_0 * a_x2;
    }

    i = 0;
    while (i < objs.len) : (i += 1) {
        objs.items(.vel)[i] += objs.items(.acc)[i] * dt;
        objs.items(.pos)[i] += objs.items(.vel)[i] * dt;
    }
}

pub fn stop() void {
    log_sim.info("Simulation terminating", .{});
    @atomicStore(bool, &is_running, false, .Release);
}

pub fn toggleMap() void {
    if (is_map_displayed) is_map_displayed = false
    else is_map_displayed = true;
}

pub inline fn moveMapLeft() void {
    cam.x += 10.0 / cam.zoom * 60.0 / gfx.getFPS();
}

pub inline fn moveMapRight() void {
    cam.x -= 10.0 / cam.zoom * 60.0 / gfx.getFPS();
}

pub inline fn moveMapUp() void {
    cam.y += 10.0 / cam.zoom * 60.0 / gfx.getFPS();
}

pub inline fn moveMapDown() void {
    cam.y -= 10.0 / cam.zoom * 60.0 / gfx.getFPS();
}

pub inline fn zoomInMap() void {
    cam.zoom *= 1.0 + 0.1 * 60.0 / gfx.getFPS();
}

pub inline fn zoomOutMap() void {
    cam.zoom *= 1.0 - 0.1 * 60.0 / gfx.getFPS();
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_sim = std.log.scoped(.sim);

var gpa = if (cfg.debug_allocator)  std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){} else
                                    std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const gravitational_constant = 6.6743015e-11;

var is_map_displayed: bool = false;
var is_running: bool = true;
var frame_time = @floatToInt(u64, 1.0/cfg.sim.fps_target*1.0e9);

const Camera = struct {
    x: f32,
    y: f32,
    zoom: f32,
};
var cam = Camera {
    .x = 0.0,
    .y = 0.0,
    .zoom = 5.0e-5,
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

