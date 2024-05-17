const std = @import("std");
const c = @import("c_stb_image.zig").c;
const cfg = @import ("config.zig");

//-----------------------------------------------------------------------------//
//   Error Sets
//-----------------------------------------------------------------------------//

const ImageError = error{
    ImageMemoryNotReleased,
    ImageLoadingFailed,
};

pub const Image = struct {
    w: u32,
    h: u32,
    data: []u8,
};

//-----------------------------------------------------------------------------//
//   Init / DeInit
//-----------------------------------------------------------------------------//

pub fn init() void {
}

pub fn deinit() void {

    // Allocated memory has to be freed with release after usage. This is typical
    // for Open GL textures. After reading and handing over to GL, the source
    // memory might be directly released

    const leaked = gpa.deinit();
    if (leaked == .leak) log_img.err("Memory leaked in GeneralPurposeAllocator", .{});
}

//-----------------------------------------------------------------------------//
//   Getter/Setter
//-----------------------------------------------------------------------------//

//-----------------------------------------------------------------------------//
//   Processing
//-----------------------------------------------------------------------------//

/// Tries to load the image at the given location. If an image has been loaded
/// before, releaseImage needs to be called first
pub fn loadImage(name: [:0]const u8) !Image {

    if (is_image_already_loaded) {
        log_img.warn("Image {s} loaded since previous image memory hasn't been released",
                     .{name});
        return ImageError.ImageMemoryNotReleased;
    } else {
        log_img.info("Loading image {s}", .{name});

        is_image_already_loaded = true;

        if (c.stbi_is_hdr(name) != 0) {
            log_img.warn("HDR not supported, yet", .{});
            return ImageError.ImageLoadingFailed;
        }
        if (c.stbi_is_16_bit(name) != 0) {
            log_img.warn("16bit not supported, yet", .{});
            return ImageError.ImageLoadingFailed;
        }

        var w_c: c_int = undefined;
        var h_c: c_int = undefined;
        var d: c_int = undefined;
        const ptr = c.stbi_load(name, &w_c, &h_c, &d, 3);
        if (ptr == null) return ImageError.ImageLoadingFailed;

        img.w = @as(u32, @intCast(w_c));
        img.h = @as(u32, @intCast(h_c));
        img.data = @ptrCast(ptr[0 .. img.w * 3 * img.h]);

        return img;
    }
}

/// Release allocated memory for image. Image should be handed over before
/// calling release
pub fn releaseImage() void {
    c.stbi_image_free(img.data.ptr);
    img = undefined;
    is_image_already_loaded = false;
}

//-----------------------------------------------------------------------------//
//   Internal
//-----------------------------------------------------------------------------//

const log_img = std.log.scoped(.img);

var gpa = if (cfg.debug_allocator)  std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){} else
                                    std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var img: Image = undefined;

/// For now, only one image is stored. After loading, it should be handed over,
/// e.g. as a texture for GL. Then, memory can be released to load another image
var is_image_already_loaded: bool = false;
