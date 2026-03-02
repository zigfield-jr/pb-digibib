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

    var enu = try mountpoints.walk(std.heap.c_allocator);
    defer enu.deinit();

    while (try enu.next(io)) |object| {
        switch (object.kind) {
            .directory => {
                if (object.depth() == 1) {
                    const band: b.Band = .{
                        .path = try std.heap.c_allocator.dupe(u8, absolute_path),
                        .name = try std.heap.c_allocator.dupe(u8, object.basename),
                    };
                    try list.append(std.heap.c_allocator, band);
                } else if (object.depth() == 2 and std.ascii.eqlIgnoreCase(object.basename, "data")) {
                    if (list.pop()) |band| {
                        var band2 = band;
                        band2.data = try std.heap.c_allocator.dupe(u8, object.basename);
                        try list.append(std.heap.c_allocator, band2);
                    }
                } else {
                    enu.leave(io);
                }
            },
            .file => {
                if (object.depth() == 3) {
                    if (std.ascii.eqlIgnoreCase(object.basename, "digibib.txt")) {
                        if (list.pop()) |band| {
                            var band2 = band;
                            band2.digibib_path = try std.heap.c_allocator.dupe(u8, object.basename);
                            try list.append(std.heap.c_allocator, band2);
                        }
                    } else if (std.ascii.eqlIgnoreCase(object.basename, "text.dki")) {
                        if (list.pop()) |band| {
                            var band2 = band;
                            band2.textDKI_path = try std.heap.c_allocator.dupe(u8, object.basename);
                            try list.append(std.heap.c_allocator, band2);
                        }
                    }
                }
            },
            else => {},
        }
    }

    return try list.toOwnedSlice(allocator);
}
