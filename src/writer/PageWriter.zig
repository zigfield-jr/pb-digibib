const std = @import("std");

const c = @cImport({
    @cInclude("inkview.h");
});

const link_color = 0xff;

const border_left_right = 40;
const border_top = 40;
const border_bottom = 100;

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

    const c_str = std.heap.c_allocator.dupeZ(u8, str) catch undefined;
    defer std.heap.c_allocator.free(c_str);

    const font_size_script = font_size(if (superscript or subscript) 0.66 * font_size_relative else font_size_relative);
    const border_top_script = if (subscript) font_size(font_size_relative) - font_size_script else 0;

    const font_name = if (bold and italic) "DejaVuSerif-BoldItalic" else if (bold) "DejaVuSerif-Bold" else if (italic) "DejaVuSerif-Italic" else "DejaVuSerif";

    const font = c.OpenFont(font_name, font_size_script, 1);
    const str_width = c.GetMultilineStringWidth(c_str.ptr, c.ScreenWidth(), font, 0); // causes bw
    const color = if (link) link_color else palette_color;
    c.SetFont(font, color);

    _ = c.FillArea(x, y, str_width, line_height(font_size_relative), c.WHITE); // cover pager
    // _ = c.DrawRect(x, y + border_top_script, str_width, font_size_script, 0xff0000);
    if (underline) {
        _ = c.FillArea(x, y + font_size(font_size_relative), str_width, font_size(font_size_relative * 0.05), color);
    }
    _ = c.DrawString(x, y + border_top_script, c_str.ptr);
    c.CloseFont(font);

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
        // _ = c.DrawRect(x, y, c.ScreenWidth() - border_left_right * 2, font_size(font_size_relative * 0.5), 0xff00);
        y += line_height(font_size_relative * 0.5);
    } else {
        y += line_height_max;
        line_height_max = 0;
    }
}

pub fn setX(x_relative: f32) void {
    skip_next_cr = false;

    x = border_left_right;

    const text_width: f32 = @floatFromInt(c.ScreenWidth() - border_left_right * 2);
    x += @intFromFloat(text_width * x_relative);
}

pub fn image(width_relative: f32, rawImage: []const u8) void {
    skip_next_cr = true;

    const text_width: f32 = @floatFromInt(c.ScreenWidth() - border_left_right * 2);
    const image_width: i32 = @intFromFloat(text_width * width_relative);

    const path = cacheImage(std.heap.c_allocator, rawImage);
    defer std.heap.c_allocator.free(path);

    const c_path = std.heap.c_allocator.dupeZ(u8, path) catch undefined;
    defer std.heap.c_allocator.free(c_path);

    const bitmap = c.LoadImageToFormat(c_path, c.kFmtRGB24);
    if (bitmap == null) {
        const rect_height = line_height(1.0);
        _ = c.DrawRect(border_left_right, y, image_width, rect_height, 0);
        y += rect_height;
        return;
    }

    const image_height = @divTrunc(bitmap.*.height * image_width, bitmap.*.width);

    _ = c.StretchBitmap(border_left_right, y, image_width, image_height, bitmap, 0);

    y += image_height;
}

pub fn imageInline(font_size_relative: f32, rawImage: []const u8) void {
    skip_next_cr = false;

    const image_height = font_size(font_size_relative * 1.1);

    const path = cacheImage(std.heap.c_allocator, rawImage);
    defer std.heap.c_allocator.free(path);

    const c_path = std.heap.c_allocator.dupeZ(u8, path) catch undefined;
    defer std.heap.c_allocator.free(c_path);

    const bitmap = c.LoadImageToFormat(c_path, c.kFmtRGB24);
    if (bitmap == null) {
        _ = c.DrawRect(x, y, image_height, image_height, 0);

        x += image_height;
        line_height_max = @max(line_height(font_size_relative), line_height_max);
        return;
    }

    const image_width = @divTrunc(bitmap.*.width * image_height, bitmap.*.height);
    _ = c.StretchBitmap(x, y, image_width, image_height, bitmap, 0);

    x += image_width;
    line_height_max = @max(line_height(font_size_relative), line_height_max);
}

pub fn pager(current_page: u32, total_pages: u32) void {
    const font = c.OpenFont("DejaVuSerif", font_size(0.85), 1);
    const icon = c.ibitmap{};
    var ipager = c.ipager{
        .page_font = font,
        .height = border_bottom,
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
        .position = c.irect{
            .x = @divTrunc(c.ScreenWidth() - 600, 2),
            .y = c.ScreenHeight() - border_bottom,
            .w = c.ScreenWidth(),
            .h = border_bottom,
        },
        .orientation = 0,
    };
    _ = c.DrawPager(&ipager);
    c.CloseFont(font);
}

// pub fn siglum(str: []u8) void {
//     const c_str = std.heap.c_allocator.dupeZ(u8, str) catch undefined;
//     defer std.heap.c_allocator.free(c_str);
//
//     const font = c.OpenFont("DejaVuSerif", font_size(0.85), 1);
//     c.SetFont(font, c.BLACK);
//     _ = c.DrawString(@divTrunc(c.ScreenWidth(), 2) + 300, c.ScreenHeight() - border_bottom + @divTrunc(border_bottom - font_size(0.85), 2), c_str.ptr);
//     c.CloseFont(font);
// }

pub fn font_size(fontsize: f32) i32 {
    const textWidth: f32 = @floatFromInt(c.ScreenWidth() - border_left_right * 2);
    return @intFromFloat(fontsize * textWidth / 27.7);
}

pub fn line_height(fontsize: f32) i32 {
    const textHeight: f32 = @floatFromInt(c.ScreenHeight() - border_top - border_bottom);
    return @intFromFloat(fontsize * textHeight / 27);
}

/// Caller owns returned memory.
fn cacheImage(allocator: std.mem.Allocator, rawImage: []const u8) []const u8 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    const absolute_path = std.fs.path.join(allocator, &[_][]const u8{ c.CACHEPATH, "digibib_image_cache" }) catch undefined;

    const cache_file = std.Io.Dir.createFileAbsolute(io, absolute_path, .{ .truncate = false }) catch undefined;
    defer cache_file.close(io);

    var cache_buffer: [1024]u8 = undefined;
    var cache_writer = cache_file.writer(io, &cache_buffer);

    cache_writer.interface.writeAll(rawImage) catch undefined;
    cache_writer.flush() catch undefined;

    return absolute_path;
}
