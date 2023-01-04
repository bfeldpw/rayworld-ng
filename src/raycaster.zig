const std = @import("std");
const gfx = @import("graphics.zig");
const map = @import("map.zig");
const plr = @import("player.zig");
const c = @import("c.zig").c;

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

pub fn showMap() void {
    const m = map.get();
    const map_cells_y = @intToFloat(f32, map.get().len);
    const map_vis_y = 0.3;
    const win_h = @intToFloat(f32, gfx.getWindowHeight());
    const f = win_h * map_vis_y / map_cells_y; // scale factor cell -> px
    const o = win_h-f*map_cells_y; // y-offset for map drawing in px

    for (m) |y,j| {
        for (y) |x,i| {
            if (x == 0) {
                c.glColor3f(0.2, 0.2, 0.2);
            } else {
                c.glColor3f(1.0, 1.0, 1.0);
            }
            gfx.drawQuad(@intToFloat(f32, i)*f, o+@intToFloat(f32, j)*f,
                         @intToFloat(f32, (i+1))*f, o+@intToFloat(f32, (j+1))*f);
        }
    }

    const w = 0.1;
    const h = 0.5;
    const x = plr.getPosX();
    const y = plr.getPosY();
    const d = plr.getDir();
    c.glColor3f(0.0, 1.0, 0.0);
    c.glBegin(c.GL_TRIANGLES);
        c.glVertex2f((x-w*@sin(d))*f, o+(y+w*@cos(d))*f);
        c.glVertex2f((x+h*@cos(d))*f, o+(y+h*@sin(d))*f);
        c.glVertex2f((x+w*@sin(d))*f, o+(y-w*@cos(d))*f);
    c.glEnd();
}

pub fn processRays() void {
    const m = map.get();
    _ = m;

    // var i: @TypeOf(gfx.getWindowWidth()) = 0;
    // while (i <= gfx.getWindowWidth()) : (i += 1) {
    //     std.log.debug("{}", .{i});
    // }
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_ray = std.log.scoped(.ray);
