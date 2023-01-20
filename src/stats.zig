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

pub const PerFrameCounter = struct {

    frame_count: u64,
    count: u64,
    max: u64,
    min: u64,
    name: []const u8,
    sum: u64,

    pub fn init(n: []const u8) PerFrameCounter {
        return PerFrameCounter {
            .count = 0,
            .frame_count = 0,
            .max = 0,
            .min = 18_446_744_073_709_551_615,
            .name = n,
            .sum = 0,
        };
    }

    pub fn finishFrame(self: *PerFrameCounter) void {
        self.sum += self.count;
        self.max = @max(self.count, self.max);
        self.min = @min(self.count, self.min);
        self.frame_count += 1;
        self.count = 0;
    }

    pub fn inc(self: *PerFrameCounter) void {
        self.count += 1;
    }

    pub fn reset(self: *PerFrameCounter) void {
        self.frame_count = 0;
        self.count = 0;
        self.max = 0;
        self.min = 18_446_744_073_709_551_615;
        self.sum = 0;
    }

    pub fn printStats(self: *PerFrameCounter) void {
        var min = self.min;
        if (self.min == 18_446_744_073_709_551_615) min = 0;

        var avg: u64 = 0;
        if (self.frame_count > 0) avg = self.sum/self.frame_count;
        log_stats.info("{s} (frames={}): min={}, max={}, avg={}",
                       .{self.name,
                         self.frame_count,
                         min,
                         self.max,
                         avg});
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
    var s = try Performance.init("Performance");
    try std.testing.expect(s.count == 0);
    try std.testing.expectEqualStrings(s.name, "Performance");
    try std.testing.expect(s.sum == 0);
    s.startMeasurement();
    std.time.sleep(42); // ns
    s.stopMeasurement();
    try std.testing.expect(s.count == 1);
    try std.testing.expect(s.sum > 0);
    s.printStats();
}

test "per-frame-counter stats" {
    var s = PerFrameCounter.init("per-frame-counter");
    try std.testing.expectEqualStrings(s.name, "per-frame-counter");
    try std.testing.expect(s.count == 0);
    try std.testing.expect(s.frame_count == 0);
    try std.testing.expect(s.max == 0);
    try std.testing.expect(s.min == 18_446_744_073_709_551_615);
    try std.testing.expect(s.sum == 0);
    s.inc();
    try std.testing.expect(s.count == 1);
    s.inc();
    try std.testing.expect(s.count == 2);
    s.finishFrame();
    try std.testing.expect(s.count == 0);
    try std.testing.expect(s.frame_count == 1);
    try std.testing.expect(s.min == 2);
    try std.testing.expect(s.max == 2);
    try std.testing.expect(s.sum == 2);
    s.inc();
    try std.testing.expect(s.count == 1);
    s.inc();
    try std.testing.expect(s.count == 2);
    s.inc();
    try std.testing.expect(s.count == 3);
    s.inc();
    try std.testing.expect(s.count == 4);
    s.finishFrame();
    try std.testing.expect(s.count == 0);
    try std.testing.expect(s.frame_count == 2);
    try std.testing.expect(s.min == 2);
    try std.testing.expect(s.max == 4);
    try std.testing.expect(s.sum == 6);
    s.printStats();
    s.reset();
    try std.testing.expect(s.count == 0);
    try std.testing.expect(s.frame_count == 0);
    try std.testing.expect(s.max == 0);
    try std.testing.expect(s.min == 18_446_744_073_709_551_615);
    try std.testing.expect(s.sum == 0);
}
