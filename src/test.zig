test "main test" {
    const fnt = @import("font_manager.zig");
    _ = fnt;
    const gfx_core = @import("gfx_core.zig");
    _ = gfx_core;
    const gfx_base = @import("gfx_base.zig");
    _ = gfx_base;
    const gui = @import("gui.zig");
    _ = gui;
    const rc = @import("raycaster.zig");
    _ = rc;
    const stats = @import("stats.zig");
    _ = stats;
    const main = @import("main.zig");
    _ = main;
}
