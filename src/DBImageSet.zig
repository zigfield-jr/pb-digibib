const std = @import("std");

pub const DBImageSet = struct {
    path: []u8 = undefined,
    image_filename: []u8 = undefined,
    // hidden: bool = undefined,
    page_number: u32 = undefined,
    // imageDescription1: []u8 = undefined,
    // imageDescription2: []u8 = undefined,

    image_address: [3]u32 = undefined,
    image_size: [3]u32 = undefined,
    // image_type: [3]u8 = undefined,

    pub fn deinit(self: *DBImageSet) void {
        std.heap.c_allocator.free(self.path);
        std.heap.c_allocator.free(self.image_filename);
    }

    pub fn small(self: *DBImageSet, allocator: std.mem.Allocator) ![]const u8 {
        const address = self.image_address[1];
        const size = self.image_size[1];
        if (address == 0 or size == 0) {
            return std.Io.Dir.OpenError.FileNotFound;
        }

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const images_file = try std.Io.Dir.openFileAbsolute(io, self.path, .{ .mode = .read_only });
        defer images_file.close(io);

        var images_buffer: [1024]u8 = undefined;
        var images_reader = images_file.reader(io, &images_buffer);

        _ = try images_reader.seekTo(address);
        return try images_reader.interface.readAlloc(allocator, size);
    }
};
