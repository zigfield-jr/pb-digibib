const std = @import("std");
const helper = @import("Helper.zig");
const cp1252 = @import("enc/cp1252.zig");
const dbis = @import("DBImageSet.zig");

/// Caller owns returned memory.
pub fn loadImageTable(allocator: std.mem.Allocator, path: []const u8, name: []const u8, images: []const u8, imageLib_path: []const u8) ![]dbis.DBImageSet {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ path, name, images, imageLib_path });
    defer std.heap.c_allocator.free(absolute_path);

    const images_file = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
    defer images_file.close(io);

    var images_buffer: [1024]u8 = undefined;
    var images_reader = images_file.reader(io, &images_buffer);

    if (!try helper.isMagic(&images_reader)) {
        _ = try images_reader.seekTo(0);
    } else {
        _ = try images_reader.interface.takeInt(u32, .little);
    }

    const total_images = try images_reader.interface.takeInt(u32, .little);
    const textstart = try images_reader.interface.takeInt(u32, .little);
    _ = try images_reader.seekBy(16);

    const image_array = try allocator.alloc(dbis.DBImageSet, total_images);

    for (0..total_images) |i| {
        image_array[i].path = try std.heap.c_allocator.dupe(u8, absolute_path);

        image_array[i].image_filename = try readImageFilename(std.heap.c_allocator, &images_reader);
        _ = try images_reader.interface.takeByte() != 0; // hidden
        image_array[i].page_number = try images_reader.interface.takeInt(u32, .little);

        try readImageDescription(&images_reader, textstart);
        try readImageDescription(&images_reader, textstart);

        for (0..5) |j| {
            const image_width = try images_reader.interface.takeInt(u16, .little);
            const image_height = try images_reader.interface.takeInt(u16, .little);
            const image_address = try images_reader.interface.takeInt(u32, .little);
            const image_size = try images_reader.interface.takeInt(u32, .little);
            _ = try images_reader.interface.takeByte(); // image_type

            if (j < 3 and image_width > 0 and image_height > 0) {
                image_array[i].image_address[j] = image_address;
                image_array[i].image_size[j] = image_size;
                // image_array[i].image_type[j] = image_type;
            }
        }
    }

    return image_array;
}

/// Caller owns returned memory.
fn readImageFilename(allocator: std.mem.Allocator, reader: *std.Io.File.Reader) ![]u8 {
    const length = try reader.interface.takeByte();
    const data = try reader.interface.take(8);
    return try std.ascii.allocLowerString(allocator, data[0..length]);
}

fn readImageDescription(reader: *std.Io.File.Reader, _: u32) !void {
    _ = try reader.interface.takeInt(u32, .little); // textdesc1
    _ = try reader.interface.takeInt(u32, .little); // textdesclength1

    // if (textdesclength1 > 0)
    // {
    //     fseek(_ftext,_textStart+textdesc1,SEEK_SET);
    //     char *mem = malloc(textdesclength1);
    //     if (fread(mem,1,textdesclength1,_ftext) != textdesclength1)
    //     {
    //         return nil;
    //     }
    //     NSData* myImageTextData = [NSData dataWithBytesNoCopy:mem length:textdesclength1 freeWhenDone:YES];
    //     imageDescription = [[NSString alloc] initWithData: myImageTextData encoding:NSWindowsCP1252StringEncoding];
    // }
}
