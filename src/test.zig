test "main test" {
    const fnt = @import("font_manager.zig");
    _ = fnt;
    const gfx_core = @import("gfx_core.zig");
    _ = gfx_core;
    // const gui = @import("gui.zig");
    const rc = @import("raycaster.zig");
    _ = rc;
    const stats = @import("stats.zig");
    _ = stats;
}
