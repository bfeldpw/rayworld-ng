// hsr = hot shader reload
//

const std = @import("std");
const atm = @import("atomic");
const lnx = std.os.linux;

comptime {
    const builtin = @import("builtin");
    if (builtin.os.tag != .linux) {
        @compileError("Something went wrong, this should have never been compiled outside of Linux.");
    }
}

pub fn init() void {
    fd = @intCast(lnx.inotify_init1(0));
    if (fd < 0) {
        log_gfx_hsr.err("Couldn't initialise inotify mechanism.", .{});
    }
    log_gfx_hsr.debug("File descriptor: {}", .{fd});
    const file = "/home/bfeld/projects/rayworld-ng/resource/shader";
    wd = @intCast(lnx.inotify_add_watch(fd, file, lnx.IN.MODIFY));
    if (wd < 0) {
        log_gfx_hsr.err("Couldn't add watch on file {s}.", .{file});
    }
    log_gfx_hsr.debug("Watch descriptor: {}", .{wd});

}

pub fn rmWatch() void {
    const r = lnx.inotify_rm_watch(fd, wd);
    _ = r;
}

pub fn readEvent() void {
    log_gfx_hsr.debug("Watching directory for hot shader reload", .{});

    const event_size = (@sizeOf(lnx.inotify_event) + std.os.PATH_MAX) * 10;
    var buf: [event_size]u8 = undefined;

    while (is_running) {
        const len = lnx.read(fd, &buf, event_size);
        _ = len;
        log_gfx_hsr.debug("Shader file(s) modified", .{});
        is_reload_triggered.value = true;
    }
    log_gfx_hsr.debug("Stopping file watch", .{});
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_gfx_hsr = std.log.scoped(.gfx_hsr);

pub var is_reload_triggered = std.atomic.Atomic(bool).init(false);
pub var is_running: bool = true;

var fd: i32 = 0;
var wd: i32 = 0;
