const std = @import("std");
const cfg = @import("config.zig");
const stats = @import("stats.zig");

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() !void {
    // Initialise planet
    try objs.append(allocator, .{
        .acc = .{0.0, 0.0},
        .vel = .{0.0, 0.0},
        .pos = .{0.0, 0.0},
        .mass = 6e24, // earth-like
        .radius = 6e6, // earth-like
    });

    var i: u32 = 0;
    while (i < 1_000) : (i += 1) {
    // Initialise station
    try objs.append(allocator, .{
        .acc = .{0.0, 0.0},
        .vel = .{0.0, 7.66e3},
        .pos = .{6413.0, 0.0},
        .mass = 500e3, // ISS-like ~ 500t
        .radius = 50, // ISS-like ~94m x 73m
    });
    }
}

pub fn deinit() void {
    objs.deinit(allocator);

    const leaked = gpa.deinit();
    if (leaked) log_sim.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn run() !void {
    try init();

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

pub fn stop() void {
    log_sim.info("Simulation terminating", .{});
    @atomicStore(bool, &is_running, false, .Release);
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_sim = std.log.scoped(.sim);

var gpa = if (cfg.debug_allocator)  std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){} else
                                    std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var is_running: bool = true;
var frame_time = @floatToInt(u64, 1.0/60.0*1.0e9);

const vec_2d = @Vector(2, f64);

const PhysicalObject = struct {
    acc: vec_2d,
    pos: vec_2d,
    vel: vec_2d,
    mass: f64,
    radius: f64,
};

/// All physically simulated objects. MultiArrayList is internally implemented
/// as a SoA (Struct of Arrays), which should be fine, here.
const Objects = std.MultiArrayList(PhysicalObject);

var objs = Objects{};

fn dynamics() void {
    var j: usize = 0;
    const dt = @splat(2, @as(f64, 1.0/60.0));
    while (j < objs.len) : (j += 1) {
        objs.items(.vel)[j] += objs.items(.acc)[j] * dt;
        objs.items(.pos)[j] += objs.items(.vel)[j] * dt;
    }
}

fn step() void {
    dynamics();

    // log_sim.debug("pos = ({d:.2}, {d:.2})",
    //               .{objs.items(.pos)[1].x, objs.items(.pos)[1].y});
}
