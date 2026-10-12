const std = @import("std");
const b = @import("Band.zig");

/// Caller owns returned memory.
pub fn searchForDigiBib(allocator: std.mem.Allocator, absolute_path: []const u8) ![]b.Band {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    var list: std.ArrayList(b.Band) = .empty;
    defer list.deinit(std.heap.c_allocator);

    var mountpoints = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{ .iterate = true });
    defer mountpoints.close(io);

    var volume_iterator = try mountpoints.walkSelectively(std.heap.c_allocator);
    defer volume_iterator.deinit();

    while (try volume_iterator.next(io)) |volume_entry| {
        if (volume_entry.kind != .directory) {
            continue;
        }

        var volume_dir = try volume_entry.dir.openDir(io, volume_entry.basename, .{ .iterate = true });

        var volume_walker = try volume_dir.walk(std.heap.c_allocator);
        defer volume_walker.deinit();

        var data: ?[]u8 = null;
        var digibib_path: ?[]u8 = null;
        var textDKI_path: ?[]u8 = null;
        var treeDKI_path: ?[]u8 = null;
        var treeDKA_path: ?[]u8 = null;

        var images: ?[]u8 = null;
        var imageLib_path: ?[]u8 = null;

        while (try volume_walker.next(io)) |entry| {
            switch (entry.kind) {
                .directory => {
                    if (entry.depth() > 1) {
                        volume_walker.leave(io);
                        continue;
                    }

                    if (std.ascii.eqlIgnoreCase(entry.basename, "data")) {
                        data = try std.heap.c_allocator.dupe(u8, entry.basename);
                    } else if (std.ascii.eqlIgnoreCase(entry.basename, "images")) {
                        images = try std.heap.c_allocator.dupe(u8, entry.basename);
                    }
                },
                .file => {
                    if (entry.depth() != 2) {
                        continue;
                    }

                    if (std.ascii.eqlIgnoreCase(entry.basename, "digibib.txt")) {
                        digibib_path = try std.heap.c_allocator.dupe(u8, entry.basename);
                    } else if (std.ascii.eqlIgnoreCase(entry.basename, "text.dki")) {
                        textDKI_path = try std.heap.c_allocator.dupe(u8, entry.basename);
                    } else if (std.ascii.eqlIgnoreCase(entry.basename, "tree.dki")) {
                        treeDKI_path = try std.heap.c_allocator.dupe(u8, entry.basename);
                    } else if (std.ascii.eqlIgnoreCase(entry.basename, "tree.dka")) {
                        treeDKA_path = try std.heap.c_allocator.dupe(u8, entry.basename);
                    } else if (std.ascii.eqlIgnoreCase(entry.basename, "images.lib")) {
                        imageLib_path = try std.heap.c_allocator.dupe(u8, entry.basename);
                    }
                },
                else => {},
            }
        }

        if (data) |data2| if (digibib_path) |digibib_path2| if (textDKI_path) |textDKI_path2| if (treeDKI_path) |treeDKI_path2| if (treeDKA_path) |treeDKA_path2| {
            try list.append(std.heap.c_allocator, .{
                .path = try std.heap.c_allocator.dupe(u8, absolute_path),
                .name = try std.heap.c_allocator.dupe(u8, volume_entry.basename),

                .data = data2,
                .digibib_path = digibib_path2,
                .textDKI_path = textDKI_path2,
                .treeDKI_path = treeDKI_path2,
                .treeDKA_path = treeDKA_path2,

                .images = images,
                .imageLib_path = imageLib_path,
            });
        };
    }

    const array = try list.toOwnedSlice(allocator);
    std.mem.sort(b.Band, array, {}, lessThan);
    return array;
}

fn lessThan(_: void, lhs: b.Band, rhs: b.Band) bool {
    return std.mem.order(u8, lhs.name, rhs.name) == .lt;
}
