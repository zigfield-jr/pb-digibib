const std = @import("std");

pub const DBImageSet = struct {
    path: []u8 = undefined,

    imageFilename: []u8 = undefined,

    hidden: bool = undefined,
    pageNumber: u32 = undefined,

    imageDescription2: []u8 = undefined,
    imageDescription1: []u8 = undefined,

    imageAddress1: u32 = undefined,
    imageSize1: u32 = undefined,
    imageType1: u8 = undefined,

    imageAddress2: u32 = undefined,
    imageSize2: u32 = undefined,
    imageType2: u8 = undefined,

    imageAddress3: u32 = undefined,
    imageSize3: u32 = undefined,
    imageType3: u8 = undefined,

    pub fn rawImage1(self: *DBImageSet, allocator: std.mem.Allocator) ![]const u8 {
        return rawImage(allocator, self.path, self.imageAddress1, self.imageSize1);
    }

    pub fn rawImage2(self: *DBImageSet, allocator: std.mem.Allocator) ![]const u8 {
        return rawImage(allocator, self.path, self.imageAddress2, self.imageSize2);
    }

    pub fn rawImage3(self: *DBImageSet, allocator: std.mem.Allocator) ![]const u8 {
        return rawImage(allocator, self.path, self.imageAddress3, self.imageSize3);
    }

    fn rawImage(allocator: std.mem.Allocator, path: []u8, address: u32, size: u32) ![]const u8 {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const images_file = try std.Io.Dir.openFileAbsolute(io, path, .{ .mode = .read_only });
        defer images_file.close(io);

        const images_buffer = try std.heap.c_allocator.alloc(u8, size);
        defer std.heap.c_allocator.free(images_buffer);

        var images_reader = images_file.reader(io, images_buffer);

        _ = try images_reader.seekTo(address);
        const mem = try images_reader.interface.take(size);

        return try allocator.dupe(u8, mem);
    }
};
