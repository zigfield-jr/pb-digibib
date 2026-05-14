const std = @import("std");
const writer = @import("writer/PageWriter.zig");
const iv = @import("inkview");

const border = 40;

var page: u8 = 0;
var pointerdown: i32 = undefined;

fn table() void {
    var utf8_char: [4]u8 = undefined;

    for (0..16) |i| {
        for (0..16) |j| {
            if (i == 0 and j == 0) {
                const c_str = std.fmt.bufPrintSentinel(&utf8_char, "", .{}, 0) catch undefined;
                cell(0, 0, c_str, true);
            }
            if (i == 0) {
                const c_str = std.fmt.bufPrintSentinel(&utf8_char, "{X}", .{j}, 0) catch undefined;
                cell(0, @intCast(j + 1), c_str, true);
            }
            if (j == 0) {
                const c_str = std.fmt.bufPrintSentinel(&utf8_char, "{X}", .{i}, 0) catch undefined;
                cell(@intCast(i + 1), 0, c_str, true);
            }

            var codepoint: u21 = @intCast(page);
            codepoint *= 256;
            codepoint += @intCast(i * 16 + j);
            const utf8_char_length = std.unicode.utf8Encode(codepoint, &utf8_char) catch undefined;
            const c_str = std.heap.c_allocator.dupeSentinel(u8, utf8_char[0..utf8_char_length], 0) catch undefined;
            defer std.heap.c_allocator.free(c_str);
            cell(@intCast(i + 1), @intCast(j + 1), c_str, false);
        }
    }
}

fn cell(row: i32, col: i32, c_str: [:0]u8, bold: bool) void {
    const font = iv.OpenFont(if (bold) "DejaVuSerif-Bold" else "DejaVuSerif", writer.font_size(1.0), 1);
    iv.SetFont(font, iv.BLACK);

    const width = @divTrunc(iv.ScreenWidth() - border * 2, 17);
    const height = @divTrunc(iv.ScreenHeight() - border * 3, 17);

    var rect = iv.irect{
        .x = col * width + border,
        .y = row * height + border,
        .w = width + 1,
        .h = height + 1,
    };

    if (bold) {
        iv.FillAreaRect(&rect, iv.LGRAY);
    }
    iv.DrawRect(rect.x, rect.y, rect.w, rect.h, iv.BLACK);
    _ = iv.DrawTextRect(rect.x, rect.y, rect.w, rect.h, c_str.ptr, iv.ALIGN_CENTER | iv.VALIGN_MIDDLE);

    iv.CloseFont(font);
}

fn main_handler(event_type: c_int, param_one: c_int, param_two: c_int) callconv(.c) c_int {
    switch (event_type) {
        iv.EVT_INIT => {
            update();
        },
        iv.EVT_KEYPRESS => {
            switch (param_one) {
                iv.IV_KEY_MENU => {
                    iv.CloseApp();
                },
                iv.IV_KEY_PREV => {
                    page -%= 1;
                    update();
                },
                iv.IV_KEY_NEXT => {
                    page +%= 1;
                    update();
                },
                else => {},
            }
        },
        iv.EVT_POINTERDOWN => {
            if (param_two > (iv.ScreenHeight() - 100)) {
                var buffer = std.mem.zeroes([8]u8);
                _ = iv.OpenKeyboard("", &buffer, 2, iv.KBD_HEX, @ptrCast(&iv_keyboardhandler));
            } else {
                pointerdown = param_one;
            }
        },
        iv.EVT_POINTERUP => {
            const pointerup: i32 = param_one;
            const delta = pointerdown - pointerup;
            if (@abs(delta) < 100) {
                return 0;
            }
            if (delta < 0) {
                page -%= 1;
            } else {
                page +%= 1;
            }
            update();
        },
        else => {},
    }

    return 0;
}

fn update() void {
    iv.ClearScreen();
    writer.pager(page, 255);
    table();
    iv.FullUpdate();
}

fn iv_keyboardhandler(text: [*c]u8) callconv(.c) void {
    if (text == null) {
        return;
    }
    const new_page = std.fmt.parseInt(i32, std.mem.span(text), 16) catch undefined;
    if (new_page < 0 or new_page > 255) {
        _ = iv.Message(1, "", "invalid pagenumber", 500);
        return;
    }
    page = @intCast(new_page);
    update();
}

pub fn main() !void {
    iv.SetCurrentApplicationAttribute(iv.APPLICATION_READER, 1); // hide context menu
    iv.InkViewMain(main_handler);
}
