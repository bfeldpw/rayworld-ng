const std = @import("std");

pub fn PerFrameTimerBuffered(comptime buffer_size: usize) type {
    return struct {
        buf: [buffer_size]u64,
        i: usize,
        count_all: u64,
        count_buf: usize,
        sum_all: u128,
        timer: std.time.Timer,

        const Self = @This();

        pub fn init() !Self {
            return .{
                .buf = undefined,
                .i = 0,
                .count_all = 0,
                .count_buf = 0,
                .sum_all = 0,
                .timer = std.time.Timer.start() catch |err| {
                    log_stats.err("Unable to initialise timer", .{});
                    return err;
                },
            };
        }

        /// Return the average time over all buffer entries in milliseconds
        pub fn getAvgBufMs(self: Self) f64 {
            var sum: u128 = 0;
            for (self.buf[0..self.count_buf-1]) |entry| {
                sum += entry;
            }
            return (@intToFloat(f64, sum) / @intToFloat(f64, self.count_buf) * 1.0e-6);
        }

        /// Return the average time since initialisation in milliseconds
        pub fn getAvgAllMs(self: Self) f64 {
            return (@intToFloat(f64, self.sum_all) / @intToFloat(f64, self.count_all) * 1.0e-6);
        }

        /// (Re-)start the timer, typically done in each frame of measurement
        pub fn start(self: *Self) void {
            self.timer.reset();
        }

        /// Stop the timer, typically done in each frame of measurement
        pub fn stop(self: *Self) void {
            const t = self.timer.read();
            self.buf[self.i] = t;
            self.i += 1;
            if (self.i >= buffer_size) self.i = 0;
            if (self.count_buf < buffer_size) self.count_buf += 1;
            self.count_all += 1;
            self.sum_all += t;
        }
    };
}

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

test "per-frame-timer stats" {
    var s = try PerFrameTimerBuffered(3).init();
    try std.testing.expect(s.buf.len == 3);
    try std.testing.expect(s.i == 0);
    try std.testing.expect(s.count_all == 0);
    try std.testing.expect(s.count_buf == 0);
    try std.testing.expect(s.sum_all == 0);
    s.start();
    std.time.sleep(42);
    s.stop();
    try std.testing.expect(s.i == 1);
    try std.testing.expect(s.count_all == 1);
    try std.testing.expect(s.count_buf == 1);
    try std.testing.expect(s.sum_all > 0);
    s.start();
    std.time.sleep(42);
    s.stop();
    s.start();
    std.time.sleep(42);
    s.stop();
    try std.testing.expect(s.i == 0);
    try std.testing.expect(s.count_all == 3);
    try std.testing.expect(s.count_buf == 3);
    s.start();
    std.time.sleep(42);
    s.stop();
    try std.testing.expect(s.i == 1);
    try std.testing.expect(s.count_all == 4);
    try std.testing.expect(s.count_buf == 3);
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
