const std = @import("std");
const swController = @import("StartWindowController.zig");
const b = @import("Band.zig");
const dbp = @import("DBPage.zig");
const writer = @import("writer/PageWriter.zig");

const c = @cImport({
    @cInclude("selection_list.h");
});

var selection_list_callbacks = c.SelectionListCallbacks{
    .Draw = draw,
    .SelectedItemChanged = selected_item_changed,
    .ItemClicked = item_clicked,
    .DrawStaticElements = draw_static_elements,
    .ItemLongClicked = item_long_clicked,
    .ScrollPositionChanged = scroll_position_changed,
};
var selection_list: ?*c.SelectionList = null;
var selection_list_visible = true;

var volumes: []b.Band = undefined;
var current_volume: b.Band = undefined;
var current_pagenumber: i32 = undefined;
var current_pagenumber_pointerdown: i32 = undefined;

fn main_handler(event_type: c_int, param_one: c_int, param_two: c_int) callconv(.c) c_int {
    switch (event_type) {
        c.EVT_INIT => {
            var volumes_buffer: [32]u8 = undefined;
            const volumes_path = std.fmt.bufPrint(&volumes_buffer, "{s}/volumes", .{c.FLASHDIR}) catch undefined;
            volumes = swController.searchForDigiBib(std.heap.c_allocator, volumes_path) catch {
                _ = c.Message(1, "", "error loading library", 500);
                return 0;
            };

            const screen_rect = c.irect{
                .y = 101,
                .w = c.ScreenWidth(),
                .h = c.ScreenHeight() - 101,
            };
            selection_list = c.SelectionList_Init(screen_rect, @ptrCast(&selection_list_callbacks), null, 196);
            _ = c.SelectionList_SetItemcount(selection_list, @intCast(volumes.len));
            _ = c.SelectionList_UseDraggableScroller(selection_list, 1);
        },
        c.EVT_SHOW => {
            if (selection_list_visible) {
                DrawLibraryHeader();
                _ = c.SelectionList_Draw(selection_list);
                _ = c.SelectionList_Update(selection_list);
            }
        },
        c.EVT_POINTERUP, c.EVT_POINTERDOWN, c.EVT_POINTERMOVE, c.EVT_POINTERLONG, c.EVT_POINTERHOLD, c.EVT_POINTERDRAG, c.EVT_POINTERCANCEL, c.EVT_POINTERCHANGED => {
            if (selection_list_visible) {
                _ = c.SelectionList_HandleEvent(selection_list, event_type, param_one, param_two);
                return 0;
            }

            if (event_type == c.EVT_POINTERDOWN) {
                if (param_two > (c.ScreenHeight() - 100)) {
                    var buffer = std.mem.zeroes([8]u8);
                    _ = c.OpenKeyboard("", &buffer, 6, c.KBD_NUMERIC, @ptrCast(&iv_keyboardhandler)); // 7 digits
                } else {
                    current_pagenumber_pointerdown = param_one;
                }
            }

            if (event_type == c.EVT_POINTERUP and c.IsKeyboardOpened() == 0) {
                const current_pagenumber_pointerup: i32 = param_one;
                const delta = current_pagenumber_pointerdown - current_pagenumber_pointerup;
                if (@abs(delta) < 100) {
                    return 0;
                }
                if (delta < 0 and current_pagenumber > 1) {
                    current_pagenumber -= 1;
                    displayPage();
                } else if (current_pagenumber < current_volume.lastpagenumber) {
                    current_pagenumber += 1;
                    displayPage();
                }
            }
        },
        c.EVT_KEYPRESS => {
            switch (param_one) {
                c.IV_KEY_MENU => {
                    if (selection_list_visible) {
                        c.SelectionList_Destroy(selection_list);
                        c.CloseApp();
                        return 0;
                    }
                    current_volume.deinit();
                    selection_list_visible = true;
                    c.ClearScreen();
                    DrawLibraryHeader();
                    _ = c.SelectionList_SetVisible(selection_list, 1);
                    _ = c.SelectionList_Update(selection_list);
                },
                c.IV_KEY_PREV => {
                    if (selection_list_visible) {
                        return 0;
                    }
                    if (current_pagenumber > 1) {
                        current_pagenumber -= 1;
                        displayPage();
                    }
                },
                c.IV_KEY_NEXT => {
                    if (selection_list_visible) {
                        return 0;
                    }
                    if (current_pagenumber < current_volume.lastpagenumber) {
                        current_pagenumber += 1;
                        displayPage();
                    }
                },
                else => {},
            }
        },
        else => {},
    }

    return 0;
}

fn DrawLibraryHeader() void {
    const font_size = writer.font_size(1.0);
    const font = c.OpenFont("DejaVuSerif", font_size, 1);
    c.SetFont(font, c.BLACK);
    _ = c.DrawRect(0, 0, c.ScreenWidth(), 100, c.WHITE);
    _ = c.DrawTextRect(0, @divTrunc(100 - font_size, 2), c.ScreenWidth(), font_size, c.GetLangText("@Library"), c.ALIGN_CENTER);
    c.CloseFont(font);
    _ = c.DrawHorizontalSeparator(0, 100, c.ScreenWidth(), c.HORIZONTAL_SEPARATOR_SOLID);
    _ = c.PartialUpdate(0, 0, c.ScreenWidth(), 101);
}

fn draw(_: ?*anyopaque, item_num: c_int, item_rect: c.irect, _: c_int, is_touched: c_int) callconv(.c) void {
    var band = volumes[@intCast(item_num)];

    // draw item

    _ = c.DrawHorizontalSeparator(item_rect.x + 20, item_rect.y + item_rect.h - 1, item_rect.w - 40, c.HORIZONTAL_SEPARATOR_SOLID);
    if (is_touched != 0) {
        _ = c.DrawRect(item_rect.x + 20, item_rect.y, item_rect.w - 40, item_rect.h - 1, c.BLACK);
    }

    // draw caption

    var caption_loaded: bool = true;
    _ = band.loadDigibibTable() catch {
        caption_loaded = false;
    };
    const caption_cstring = std.heap.c_allocator.dupeZ(u8, if (caption_loaded) band.caption else band.name) catch undefined;
    defer std.heap.c_allocator.free(caption_cstring);

    const font = c.OpenFont("DejaVuSerif", writer.font_size(1.0), 1);
    c.SetFont(font, c.BLACK);
    _ = c.DrawTextRect(item_rect.x + 170, item_rect.y + 20, item_rect.w - 210, item_rect.h - 40 - 1, caption_cstring, c.ALIGN_LEFT | c.VALIGN_MIDDLE);
    c.CloseFont(font);

    // draw cover

    _ = c.DrawRect(item_rect.x + 40, item_rect.y + 20, 110, 155, c.BLACK);
    const cover_filename = band.loadCoverImage(std.heap.c_allocator) catch {
        return;
    };
    defer std.heap.c_allocator.free(cover_filename);

    const cover_path = std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ band.path, band.name, band.data, cover_filename }) catch {
        return;
    };
    defer std.heap.c_allocator.free(cover_path);

    const cover_path_cstring = std.heap.c_allocator.dupeZ(u8, cover_path) catch undefined;
    defer std.heap.c_allocator.free(cover_path_cstring);

    const bitmap = c.LoadBitmap(cover_path_cstring);
    if (bitmap == null) {
        return;
    }
    _ = c.DrawBitmapRect(item_rect.x + 40, item_rect.y + 20, 110, 155, bitmap, c.ALIGN_CENTER | c.VALIGN_MIDDLE);
    _ = c.DrawRect(item_rect.x + 40, item_rect.y + 20, 110, 155, c.BLACK);
}

fn selected_item_changed(_: ?*anyopaque, _: c_int) callconv(.c) void {}

fn item_clicked(_: ?*anyopaque, item_num: c_int, _: c_int, _: c_int) callconv(.c) void {
    current_volume = volumes[@intCast(item_num)];

    // load volume

    current_volume.initWithPath() catch {
        _ = c.Message(1, "", "error loading volume", 500);
        return;
    };

    // hide library

    selection_list_visible = false;
    _ = c.SelectionList_SetVisible(selection_list, 0);
    _ = c.SelectionList_Update(selection_list);

    // load first page

    current_pagenumber = 1;
    displayPage();
}

fn draw_static_elements(_: ?*anyopaque, _: c.irect) callconv(.c) void {}

fn item_long_clicked(_: ?*anyopaque, _: c_int, _: c_int, _: c_int) callconv(.c) void {}

fn scroll_position_changed(_: ?*anyopaque, _: c_int, _: c_int) callconv(.c) void {}

fn iv_keyboardhandler(text: [*c]u8) callconv(.c) void {
    if (text == null) {
        return;
    }
    const new_pagenumber = std.fmt.parseInt(i32, std.mem.span(text), 10) catch {
        _ = c.Message(1, "", "error parsing pagenumber", 500);
        return;
    };
    if (new_pagenumber < 1 or new_pagenumber > current_volume.lastpagenumber) {
        _ = c.Message(1, "", "invalid pagenumber", 500);
        return;
    }
    current_pagenumber = new_pagenumber;
    displayPage();
}

pub fn displayPage() void {
    var page = current_volume.textPageData(current_pagenumber) catch {
        _ = c.Message(1, "", "error loading previous page", 500);
        return;
    };
    defer page.deinit();

    c.ClearScreen();
    page.displayPageInView(current_volume.imageDict) catch {
        _ = c.Message(1, "", "error rendering previous page", 500);
        return;
    };
    c.FullUpdate();
}

pub fn main() !void {
    c.SetCurrentApplicationAttribute(c.APPLICATION_READER, 1); // hide context menu
    c.InkViewMain(main_handler);
}
