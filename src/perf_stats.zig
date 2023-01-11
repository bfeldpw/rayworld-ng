const std = @import("std");

pub const Performance = struct {

    count: u64,
    name: []const u8,
    sum: u64,
    timer: std.time.Timer,

    pub fn init(n: []const u8) !Performance {
        return Performance {
            .count = 0,
            .name = n,
            .sum = 0,
            .timer = try std.time.Timer.start(),
        };
    }

    pub fn printStats(self: *Performance) void {
        log_stats.info("{s} (n={}): {d:.2} ms",
                       .{self.name,
                         self.count,
                         @intToFloat(f64, self.sum)/@intToFloat(f64, self.count) * 1e-6});
    }

    pub fn startMeasurement(self: *Performance) void {
        self.timer.reset();
    }

    pub fn stopMeasurement(self: *Performance) void {
        self.sum += self.timer.read();
        self.count += 1;
    }
};

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_stats = std.log.scoped(.stats);

//-----------------------------------------------------------------------------//
//   Tests
//-----------------------------------------------------------------------------//

test "performance stats" {
    var s = try Performance.init("test");
    try std.testing.expect(s.count == 0);
    try std.testing.expectEqualStrings(s.name, "test");
    try std.testing.expect(s.sum == 0);
    s.startMeasurement();
    std.time.sleep(42); // ns
    s.stopMeasurement();
    try std.testing.expect(s.count == 1);
    try std.testing.expect(s.sum > 0);
    s.printStats();
}
