const std = @import("std");
const swController = @import("StartWindowController.zig");
const b = @import("Band.zig");
const dbp = @import("DBPage.zig");
const writer = @import("writer/PageWriter.zig");
const iv = @import("inkview");

var library_list_callbacks = iv.SelectionListCallbacks{
    .Draw = libraryDraw,
    .SelectedItemChanged = librarySelectedItemChanged,
    .ItemClicked = libraryItemClicked,
    .DrawStaticElements = libraryDrawStaticElements,
    .ItemLongClicked = libraryItemLongClicked,
    .ScrollPositionChanged = libraryScrollPositionChanged,
};
var library_list: ?*iv.SelectionList = null;
var library_list_visible = true;

var toc_list_callbacks = iv.SelectionListCallbacks{
    .Draw = tocDraw,
    .SelectedItemChanged = tocSelectedItemChanged,
    .ItemClicked = tocItemClicked,
    .DrawStaticElements = tocDrawStaticElements,
    .ItemLongClicked = tocItemLongClicked,
    .ScrollPositionChanged = tocScrollPositionChanged,
};
var toc_list: ?*iv.SelectionList = null;
var toc_list_visible = false;

var volumes: []b.Band = undefined;
var current_volume: b.Band = undefined;
var current_pagenumber: u32 = undefined;
var current_pagenumber_pointerdown: i32 = undefined;

fn main_handler(event_type: c_int, param_one: c_int, param_two: c_int) callconv(.c) c_int {
    switch (event_type) {
        iv.EVT_INIT => {
            var volumes_buffer: [32]u8 = undefined;
            const volumes_path = std.fmt.bufPrint(&volumes_buffer, "{s}/volumes", .{iv.FLASHDIR}) catch undefined;
            volumes = swController.searchForDigiBib(std.heap.c_allocator, volumes_path) catch {
                _ = iv.Message(1, "", "error loading library", 500);
                return 0;
            };

            const library_rect = iv.irect{
                .y = 101,
                .w = iv.ScreenWidth(),
                .h = iv.ScreenHeight() - 101,
            };
            library_list = iv.SelectionList_Init(library_rect, @ptrCast(&library_list_callbacks), null, 196);
            _ = iv.SelectionList_SetItemcount(library_list, @intCast(volumes.len));
            _ = iv.SelectionList_UseDraggableScroller(library_list, 1);

            const toc_rect = iv.irect{
                .y = @divTrunc(iv.ScreenHeight(), 2),
                .w = iv.ScreenWidth(),
                .h = @divTrunc(iv.ScreenHeight(), 2),
            };
            toc_list = iv.SelectionList_Init(toc_rect, @ptrCast(&toc_list_callbacks), null, writer.line_height(1.0));
            _ = iv.SelectionList_UseDraggableScroller(toc_list, 1);
            _ = iv.SelectionList_SetScrollerOffset(toc_list, 1, 0);
            _ = iv.SelectionList_SetVisible(toc_list, 0);
        },
        iv.EVT_SHOW => {
            if (library_list_visible) {
                DrawLibraryHeader();
                _ = iv.SelectionList_Draw(library_list);
                _ = iv.SelectionList_Update(library_list);
            }
        },
        iv.EVT_POINTERUP, iv.EVT_POINTERDOWN, iv.EVT_POINTERMOVE, iv.EVT_POINTERLONG, iv.EVT_POINTERHOLD, iv.EVT_POINTERDRAG, iv.EVT_POINTERCANCEL, iv.EVT_POINTERCHANGED => {
            if (library_list_visible) {
                _ = iv.SelectionList_HandleEvent(library_list, event_type, param_one, param_two);
                return 0;
            }

            if (toc_list_visible) {
                if (event_type == iv.EVT_POINTERUP and param_two < @divTrunc(iv.ScreenHeight(), 2)) {
                    toc_list_visible = false;
                    _ = iv.SelectionList_SetVisible(toc_list, 0);
                    _ = iv.SelectionList_Update(toc_list);

                    displayPage();
                    return 0;
                }

                _ = iv.SelectionList_HandleEvent(toc_list, event_type, param_one, param_two);
                return 0;
            }

            if (event_type == iv.EVT_POINTERDOWN) {
                if (param_two > (iv.ScreenHeight() - 100)) {
                    var buffer = std.mem.zeroes([8]u8);
                    _ = iv.OpenKeyboard("", &buffer, 6, iv.KBD_NUMERIC, @ptrCast(&iv_keyboardhandler)); // 7 digits
                } else {
                    current_pagenumber_pointerdown = param_one;
                }
            }

            if (event_type == iv.EVT_POINTERUP and iv.IsKeyboardOpened() == 0) {
                const current_pagenumber_pointerup: i32 = param_one;
                const delta = current_pagenumber_pointerdown - current_pagenumber_pointerup;
                if (@abs(delta) < 100) {
                    const tree_array = current_volume.tree_array;

                    for (tree_array, 0..) |entry, i| {
                        if (current_pagenumber <= entry.textpagenumber) {
                            _ = iv.SelectionList_SetSelectedItem(toc_list, @intCast(i));
                            break;
                        }
                    }

                    toc_list_visible = true;
                    _ = iv.SelectionList_SetVisible(toc_list, 1);
                    _ = iv.SelectionList_Draw(toc_list);
                    _ = iv.SelectionList_Update(toc_list);

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
        iv.EVT_KEYPRESS => {
            switch (param_one) {
                iv.IV_KEY_MENU => {
                    if (library_list_visible) {
                        iv.SelectionList_Destroy(library_list);
                        iv.SelectionList_Destroy(toc_list);
                        iv.CloseApp();
                        return 0;
                    }

                    toc_list_visible = false;
                    _ = iv.SelectionList_SetVisible(toc_list, 0);
                    _ = iv.SelectionList_Update(toc_list);

                    // FIXME current_volume.deinit();

                    iv.ClearScreen();

                    DrawLibraryHeader();

                    library_list_visible = true;
                    _ = iv.SelectionList_SetVisible(library_list, 1);
                    _ = iv.SelectionList_Update(library_list);
                },
                iv.IV_KEY_PREV => {
                    if (library_list_visible) {
                        return 0;
                    }
                    if (current_pagenumber > 1) {
                        current_pagenumber -= 1;
                        displayPage();
                    }
                },
                iv.IV_KEY_NEXT => {
                    if (library_list_visible) {
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
    _ = iv.DrawRect(0, 0, iv.ScreenWidth(), 100, iv.WHITE);

    const font_size = writer.font_size(1.0);
    const font = iv.OpenFont("DejaVuSerif", font_size, 1);
    iv.SetFont(font, iv.BLACK);

    const str = iv.GetLangText("@Library");
    const str_width = iv.GetMultilineStringWidth(str, iv.ScreenWidth(), font, 0);
    _ = iv.DrawString(@divTrunc(iv.ScreenWidth() - str_width, 2), @divTrunc(100 - font_size, 2), str);
    iv.CloseFont(font);

    _ = iv.DrawHorizontalSeparator(0, 100, iv.ScreenWidth(), iv.HORIZONTAL_SEPARATOR_SOLID);

    _ = iv.PartialUpdate(0, 0, iv.ScreenWidth(), 101);
}

fn libraryDraw(_: ?*anyopaque, item_num: c_int, item_rect: iv.irect, _: c_int, is_touched: c_int) callconv(.c) void {
    var band = volumes[@intCast(item_num)];

    // draw item

    _ = iv.DrawHorizontalSeparator(item_rect.x + 20, item_rect.y + item_rect.h - 1, item_rect.w - 40, iv.HORIZONTAL_SEPARATOR_SOLID);
    if (is_touched != 0) {
        _ = iv.DrawRect(item_rect.x + 20, item_rect.y, item_rect.w - 40, item_rect.h - 1, iv.BLACK);
    }

    // draw caption

    var caption_loaded: bool = true;
    _ = band.loadDigibibTable() catch {
        caption_loaded = false;
    };
    const caption_cstring = std.heap.c_allocator.dupeSentinel(u8, if (caption_loaded) band.caption else band.name, 0) catch undefined;
    defer std.heap.c_allocator.free(caption_cstring);

    const font = iv.OpenFont("DejaVuSerif", writer.font_size(1.0), 1);
    iv.SetFont(font, iv.BLACK);
    _ = iv.DrawTextRect(item_rect.x + 170, item_rect.y + 20, item_rect.w - 210, item_rect.h - 40 - 1, caption_cstring, iv.ALIGN_LEFT | iv.VALIGN_MIDDLE);
    iv.CloseFont(font);

    // draw cover

    _ = iv.DrawRect(item_rect.x + 40, item_rect.y + 20, 110, 155, iv.BLACK);
    const cover_filename = band.loadCoverImage(std.heap.c_allocator) catch {
        return;
    };
    defer std.heap.c_allocator.free(cover_filename);

    const cover_path = std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ band.path, band.name, band.data, cover_filename }) catch {
        return;
    };
    defer std.heap.c_allocator.free(cover_path);

    const cover_path_cstring = std.heap.c_allocator.dupeSentinel(u8, cover_path, 0) catch undefined;
    defer std.heap.c_allocator.free(cover_path_cstring);

    const bitmap = iv.LoadBitmap(cover_path_cstring);
    if (bitmap == null) {
        return;
    }
    _ = iv.DrawBitmapRect(item_rect.x + 40, item_rect.y + 20, 110, 155, bitmap, iv.ALIGN_CENTER | iv.VALIGN_MIDDLE);
    _ = iv.DrawRect(item_rect.x + 40, item_rect.y + 20, 110, 155, iv.BLACK);
}

fn librarySelectedItemChanged(_: ?*anyopaque, _: c_int) callconv(.c) void {}

fn libraryItemClicked(_: ?*anyopaque, item_num: c_int, _: c_int, _: c_int) callconv(.c) void {
    current_volume = volumes[@intCast(item_num)];

    // load volume

    current_volume.initWithPath() catch {
        _ = iv.Message(1, "", "error loading volume", 500);
        return;
    };

    // hide library

    library_list_visible = false;
    _ = iv.SelectionList_SetVisible(library_list, 0);
    _ = iv.SelectionList_Update(library_list);

    // init toc

    _ = iv.SelectionList_SetItemcount(toc_list, @intCast(current_volume.tree_array.len));

    // load first page

    current_pagenumber = 1;
    displayPage();
}

fn libraryDrawStaticElements(_: ?*anyopaque, _: iv.irect) callconv(.c) void {}

fn libraryItemLongClicked(_: ?*anyopaque, _: c_int, _: c_int, _: c_int) callconv(.c) void {}

fn libraryScrollPositionChanged(_: ?*anyopaque, _: c_int, _: c_int) callconv(.c) void {}

fn tocDraw(_: ?*anyopaque, item_num: c_int, item_rect: iv.irect, is_selected: c_int, _: c_int) callconv(.c) void {
    if (is_selected != 0) {
        _ = iv.FillAreaRect(&item_rect, iv.LGRAY);
    }

    const entry = current_volume.tree_array[@intCast(item_num)];

    const name_cstring = std.heap.c_allocator.dupeSentinel(u8, entry.name, 0) catch undefined;
    defer std.heap.c_allocator.free(name_cstring);

    var page_buffer: [8]u8 = undefined;
    const page_cstring = std.fmt.bufPrintSentinel(&page_buffer, "{d}", .{entry.textpagenumber}, 0) catch undefined;

    const font = iv.OpenFont("DejaVuSerif", writer.font_size(1.0), 1);
    iv.SetFont(font, iv.BLACK);
    _ = iv.DrawTextRect(item_rect.x + 40, item_rect.y, @divTrunc((item_rect.w - 80) * 4, 5), item_rect.h, name_cstring, iv.ALIGN_LEFT | iv.VALIGN_MIDDLE | iv.DOTS);
    _ = iv.DrawTextRect(item_rect.x + 40 + @divTrunc((item_rect.w - 80) * 4, 5), item_rect.y, @divTrunc(item_rect.w - 80, 5), item_rect.h, page_cstring, iv.ALIGN_RIGHT | iv.VALIGN_MIDDLE);
    iv.CloseFont(font);
}

fn tocSelectedItemChanged(_: ?*anyopaque, _: c_int) callconv(.c) void {}

fn tocItemClicked(_: ?*anyopaque, item_num: c_int, _: c_int, _: c_int) callconv(.c) void {
    const entry = current_volume.tree_array[@intCast(item_num)];
    if (current_pagenumber != entry.textpagenumber) {
        current_pagenumber = entry.textpagenumber;
        displayPage();
    }

    _ = iv.SelectionList_SetSelectedItem(toc_list, item_num);
    _ = iv.SelectionList_Update(toc_list);
}

fn tocDrawStaticElements(_: ?*anyopaque, screen_rect: iv.irect) callconv(.c) void {
    _ = iv.DrawHorizontalSeparator(screen_rect.x, screen_rect.y, iv.ScreenWidth(), iv.HORIZONTAL_SEPARATOR_SOLID);
}

fn tocItemLongClicked(_: ?*anyopaque, _: c_int, _: c_int, _: c_int) callconv(.c) void {}

fn tocScrollPositionChanged(_: ?*anyopaque, _: c_int, _: c_int) callconv(.c) void {}

fn iv_keyboardhandler(text: [*c]u8) callconv(.c) void {
    if (text == null) {
        return;
    }
    const new_pagenumber = std.fmt.parseInt(u32, std.mem.span(text), 10) catch {
        _ = iv.Message(1, "", "error parsing pagenumber", 500);
        return;
    };
    if (new_pagenumber < 1 or new_pagenumber > current_volume.lastpagenumber) {
        _ = iv.Message(1, "", "invalid pagenumber", 500);
        return;
    }
    current_pagenumber = new_pagenumber;
    displayPage();
}

pub fn displayPage() void {
    var page = current_volume.textPageData(current_pagenumber) catch {
        _ = iv.Message(1, "", "error loading previous page", 500);
        return;
    };
    defer page.deinit();

    iv.ClearScreen();
    page.displayPageInView(current_volume.imageDict) catch {
        _ = iv.Message(1, "", "error rendering previous page", 500);
        return;
    };
    if (toc_list_visible) {
        _ = iv.PartialUpdate(0, 0, iv.ScreenWidth(), @divTrunc(iv.ScreenHeight(), 2));
    } else {
        iv.FullUpdate();
    }
}

pub fn main() !void {
    iv.SetCurrentApplicationAttribute(iv.APPLICATION_READER, 1); // hide context menu
    iv.InkViewMain(main_handler);
}
