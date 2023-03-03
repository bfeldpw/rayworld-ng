const std = @import("std");

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//
pub var is_running: bool = true;

pub fn run() !void {
    var timer = try std.time.Timer.start();

    log_sim.info("Starting simulation", .{});

    while (is_running) {
        step();

        const t = timer.read();

        const t_step = @subWithOverflow(frame_time, t);
        if (t_step[1] == 0) std.time.sleep(t_step[0]);

        timer.reset();
    }
}

pub fn stop() void {
    log_sim.info("Simulation terminating", .{});
    @atomicStore(bool, &is_running, false, .Release);
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_sim = std.log.scoped(.sim);

var i: u64 = 0;
var frame_time = @floatToInt(u64, 1.0/10.0*1.0e9);

fn step() void {
    log_sim.debug("Background simulation running, counting seconds just for fun {}", .{i});
    i += 1;
}
