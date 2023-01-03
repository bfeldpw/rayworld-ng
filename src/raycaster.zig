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
    const f = 40.0;

    for (m) |y, j| {
        for (y) |_,i| {
            // log_ray.debug("{},{}", .{i, j});
            if (m.*[i][j] == 0) {
                c.glColor3f(0.2, 0.2, 0.2);
            } else {
                c.glColor3f(1.0, 1.0, 1.0);
            }
            gfx.drawQuad(10+@intToFloat(f32, i)*f, 10+@intToFloat(f32, j)*f,
                         10+@intToFloat(f32, (i+1))*f, 10+@intToFloat(f32, (j+1))*f);
        }
    }

    const w = 0.1;
    const h = 0.5;
    c.glColor3f(0.0, 1.0, 0.0);
    c.glBegin(c.GL_TRIANGLES);
    c.glVertex2f(10+(plr.getPosX()-w*@sin(plr.getDir()))*f, 10+(plr.getPosY()+w*@cos(plr.getDir()))*f);
    c.glVertex2f(10+(plr.getPosX()+h*@cos(plr.getDir()))*f, 10+(plr.getPosY()+h*@sin(plr.getDir()))*f);
    c.glVertex2f(10+(plr.getPosX()+w*@sin(plr.getDir()))*f, 10+(plr.getPosY()-w*@cos(plr.getDir()))*f);
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
