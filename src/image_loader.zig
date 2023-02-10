const std = @import("std");
const c = @import("c.zig").c;
const cfg = @import ("config.zig");
const zstbi = @import("zstbi");

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const ImageError = error{
    ImageMemoryNotReleased,
    ImageLoadingFailed,
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() void {
    zstbi.init(allocator);
}

pub fn deinit() void {
    zstbi.deinit();

    // Allocated memory has to be freed with release after usage. This is typical
    // for Open GL textures. After reading and handing over to GL, the source
    // memory might be directly released

    const leaked = gpa.deinit();
    if (leaked) log_img.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

/// Tries to load the bmp at the given location. If an image has been loaded
/// before, releaseImage needs to be called first
pub fn loadImage(name: [:0]const u8) !*zstbi.Image {

    if (is_image_already_loaded) {
        log_img.warn("Image {s} loaded since previous image memory hasn't been released",
                     .{name});
        return ImageError.ImageMemoryNotReleased;
    } else {
        log_img.info("Loading image {s}", .{name});

        is_image_already_loaded = true;
        img = try zstbi.Image.init(name, 3);
        // var img0 = try zstbi.Image.init(name, 3);
        // defer img0.deinit();
        // img = img0.resize(2000, 1333);
        return &img;
    }
}

/// Release allocated memory for image. Image should be handed over before
/// calling release
pub fn releaseImage() void {
    img.deinit();
    is_image_already_loaded = false;
}

pub fn initDrawTest() c.GLuint {
    var tex: c.GLuint = 0;
    c.glGenTextures(1, &tex);
    c.glBindTexture(c.GL_TEXTURE_2D, tex);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

    c.glTexImage2D(c.GL_TEXTURE_2D, 0, 3, @truncate(u16, img.width), @truncate(u16, img.height), 0,
                   c.GL_RGB, c.GL_UNSIGNED_BYTE, @ptrCast([*c]u8, img.data));
    return tex;
}


pub fn processDrawTest(tex: c.GLuint) void {
    c.glEnable(c.GL_TEXTURE_2D);
    c.glBindTexture(c.GL_TEXTURE_2D, tex);

    const u_0 = 0;
    const u_1 = 1;
    const v_0 = 0;
    const v_1 = 1;
    const offset = 20;
    const px_size = 1000;

    c.glBegin(c.GL_QUADS);

    c.glColor4f(1.0, 1.0, 1.0, 1.0);
    c.glTexCoord2f(u_0, v_0); c.glVertex2f(offset, offset);
    c.glTexCoord2f(u_1, v_0); c.glVertex2f(offset+px_size, offset);
    c.glTexCoord2f(u_1, v_1); c.glVertex2f(offset+px_size, offset+px_size);
    c.glTexCoord2f(u_0, v_1); c.glVertex2f(offset, offset+px_size);

    c.glEnd();

    c.glBegin(c.GL_LINES);
    c.glTexCoord2f(u_0, v_0); c.glVertex2f(offset+1300, offset);
    c.glTexCoord2f(u_0, v_1); c.glVertex2f(offset+1300, offset+px_size);
    c.glEnd();

    c.glDisable(c.GL_TEXTURE_2D);
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_img = std.log.scoped(.img);

var gpa = if (cfg.debug_allocator)  std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){} else
                                    std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var img: zstbi.Image = undefined;

/// For now, only one image is stored. After loading, it should be handed over,
/// e.g. as a texture for GL. Then, memory can be released to load another image
var is_image_already_loaded: bool = false;
