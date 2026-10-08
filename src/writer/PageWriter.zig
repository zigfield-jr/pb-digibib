const std = @import("std");
const iv = @import("inkview");

const debug = false;

const link_color = 0xff;

const border_left_right = 32;
const border_top = 24;

const pager_height = 96;

var x: i32 = undefined;
var y: i32 = undefined;
var line_height_max: i32 = undefined;
var skip_next_cr: bool = undefined;

pub fn reset() void {
    x = border_left_right;
    y = border_top;
    line_height_max = 0;
    skip_next_cr = true;
}

pub fn write(str: []u8, spaces: bool, bold: bool, italic: bool, superscript: bool, subscript: bool, link: bool, underline: bool, font_size_relative: f32, palette_color: i32) void {
    skip_next_cr = false;

    const c_str = std.heap.c_allocator.dupeSentinel(u8, str, 0) catch undefined;
    defer std.heap.c_allocator.free(c_str);

    const font_size_script = font_size(if (superscript or subscript) 0.66 * font_size_relative else font_size_relative);
    const border_top_script = if (subscript) font_size(font_size_relative) - font_size_script else 0;

    const font_name = if (bold and italic) "DejaVuSans-BoldOblique" else if (bold) "DejaVuSans-Bold" else if (italic) "DejaVuSans-Oblique" else "DejaVuSans";

    const font = iv.OpenFont(font_name, font_size_script, 1);
    const str_width = iv.GetMultilineStringWidth(c_str.ptr, iv.ScreenWidth(), font, 0); // causes bw
    const color = if (link) link_color else palette_color;
    iv.SetFont(font, color);

    _ = iv.FillArea(x, y, str_width, line_height(font_size_relative), iv.WHITE); // cover pager
    if (debug) {
        _ = iv.DrawRect(x, y + border_top_script, str_width, font_size_script, 0xff0000);
    }
    if (underline) {
        _ = iv.FillArea(x, y + font_size(font_size_relative), str_width, font_size(font_size_relative * 0.05), color);
    }
    _ = iv.DrawString(x, y + border_top_script, c_str.ptr);
    iv.CloseFont(font);

    x += str_width;
    if (!spaces) {
        line_height_max = @max(line_height(font_size_relative), line_height_max);
    }
}

pub fn cr(font_size_relative: f32) void {
    if (skip_next_cr) {
        skip_next_cr = false;
        return;
    }
    x = border_left_right;
    if (line_height_max == 0) {
        if (debug) {
            _ = iv.DrawRect(x, y, iv.ScreenWidth() - border_left_right * 2, font_size(font_size_relative * 0.5), 0xff00);
        }
        y += line_height(font_size_relative * 0.5);
    } else {
        y += line_height_max;
        line_height_max = 0;
    }
}

pub fn setX(x_relative: f32) void {
    skip_next_cr = false;

    x = border_left_right;

    const text_width: f32 = @floatFromInt(iv.ScreenWidth() - border_left_right * 2);
    x += @intFromFloat(text_width * x_relative);
}

pub fn image(width_relative: f32, rawImage: []const u8) void {
    skip_next_cr = true;

    const text_width: f32 = @floatFromInt(iv.ScreenWidth() - border_left_right * 2);
    const image_width: i32 = @intFromFloat(text_width * width_relative);

    const path = cacheImage(std.heap.c_allocator, rawImage);
    defer std.heap.c_allocator.free(path);

    const c_path = std.heap.c_allocator.dupeSentinel(u8, path, 0) catch undefined;
    defer std.heap.c_allocator.free(c_path);

    const bitmap = iv.LoadImageToFormat(c_path, iv.kFmtRGB24);
    if (bitmap == null) {
        const rect_height = line_height(1.0);
        _ = iv.DrawRect(border_left_right, y, image_width, rect_height, 0);
        y += rect_height;
        return;
    }

    const image_height = @divTrunc(bitmap.*.height * image_width, bitmap.*.width);

    _ = iv.StretchBitmap(border_left_right, y, image_width, image_height, bitmap, 0);

    y += image_height;
}

pub fn imageInline(font_size_relative: f32, raw_image: []const u8) void {
    skip_next_cr = false;

    const path = cacheImage(std.heap.c_allocator, raw_image);
    defer std.heap.c_allocator.free(path);

    const c_path = std.heap.c_allocator.dupeSentinel(u8, path, 0) catch undefined;
    defer std.heap.c_allocator.free(c_path);

    const bitmap = iv.LoadImageToFormat(c_path, iv.kFmtRGB24);
    if (bitmap == null) {
        var utf8_char: [4]u8 = undefined;
        const utf8_char_length = std.unicode.utf8Encode(0xfffd, &utf8_char) catch undefined;
        write(utf8_char[0..utf8_char_length], false, false, false, false, false, false, false, font_size_relative, 0);
        return;
    }

    const image_height = font_size(font_size_relative * 1.15);
    const image_width = @divTrunc(bitmap.*.width * image_height, bitmap.*.height);
    _ = iv.StretchBitmap(x, y, image_width, image_height, bitmap, 0);
    if (debug) {
        _ = iv.DrawRect(x, y, image_width, font_size(font_size_relative), 0xffff);
    }

    x += image_width;
    line_height_max = @max(line_height(font_size_relative), line_height_max);
}

pub fn pager(current_page: u32, total_pages: u32) void {
    const font = iv.OpenFont("DejaVuSans", font_size(0.85), 1);
    const icon = iv.ibitmap{};
    var ipager = iv.ipager{
        .page_font = font,
        .height = pager_height,
        .indent_horizontal = 0,
        .left_width = 100,
        .page_width = 400,
        .rigth_width = 100,
        // .separator_size = 1,
        // .separator_color = c.LGRAY,
        .icon_left = &icon,
        .icon_right = &icon,
        .current_page = @intCast(current_page),
        .total_pages = @intCast(total_pages),
        .position = iv.irect{
            .x = @divTrunc(iv.ScreenWidth() - 600, 2),
            .y = iv.ScreenHeight() - pager_height,
            .w = iv.ScreenWidth(),
            .h = pager_height,
        },
        .orientation = 0,
    };
    _ = iv.DrawPager(&ipager);
    iv.CloseFont(font);
}

// pub fn siglum(str: []u8) void {
//     const c_str = std.heap.c_allocator.dupeZ(u8, str) catch undefined;
//     defer std.heap.c_allocator.free(c_str);
//
//     const font = c.OpenFont("DejaVuSans", font_size(0.85), 1);
//     c.SetFont(font, c.BLACK);
//     _ = c.DrawString(@divTrunc(c.ScreenWidth(), 2) + 300, c.ScreenHeight() - pager_height + @divTrunc(pager_height - font_size(0.85), 2), c_str.ptr);
//     c.CloseFont(font);
// }

pub fn font_size(fontsize: f32) i32 {
    const textWidth: f32 = @floatFromInt(iv.ScreenWidth() - border_left_right * 2);
    return @intFromFloat(fontsize * textWidth / 27.9);
}

pub fn line_height(fontsize: f32) i32 {
    const textHeight: f32 = @floatFromInt(iv.ScreenHeight() - border_top - pager_height);
    return @intFromFloat(fontsize * textHeight / 27.1);
}

/// Caller owns returned memory.
fn cacheImage(allocator: std.mem.Allocator, rawImage: []const u8) []const u8 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    const absolute_path = std.fs.path.join(allocator, &[_][]const u8{ iv.CACHEPATH, "digibib_image_cache" }) catch undefined;

    const cache_file = std.Io.Dir.createFileAbsolute(io, absolute_path, .{ .truncate = false }) catch undefined;
    defer cache_file.close(io);

    var cache_buffer: [1024]u8 = undefined;
    var cache_writer = cache_file.writer(io, &cache_buffer);

    cache_writer.interface.writeAll(rawImage) catch undefined;
    cache_writer.flush() catch undefined;

    return absolute_path;
}
