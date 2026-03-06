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

    const totalImages = try images_reader.interface.takeInt(u32, .little);
    const textstart = try images_reader.interface.takeInt(u32, .little);
    _ = try images_reader.seekBy(16);

    const imageArray = try allocator.alloc(dbis.DBImageSet, totalImages);

    const path_dupe = try std.heap.c_allocator.dupe(u8, absolute_path);
    for (0..totalImages) |i| {
        imageArray[i].path = path_dupe;

        const imageFilename = try readImageFilename(std.heap.c_allocator, &images_reader);
        defer std.heap.c_allocator.free(imageFilename);

        imageArray[i].imageFilename = try std.heap.c_allocator.dupe(u8, imageFilename);
        imageArray[i].hidden = try images_reader.interface.takeByte() != 0;
        imageArray[i].pageNumber = try images_reader.interface.takeInt(u32, .little);

        try readImageDescription(&images_reader, textstart);
        try readImageDescription(&images_reader, textstart);

        for (1..6) |j| {
            const weite = try images_reader.interface.takeInt(u16, .little);
            const hoehe = try images_reader.interface.takeInt(u16, .little);
            const adresse = try images_reader.interface.takeInt(u32, .little);
            const imagesize = try images_reader.interface.takeInt(u32, .little);
            const imageType = try images_reader.interface.takeByte();

            if (weite > 0 and hoehe > 0) {
                switch (j) {
                    1 => {
                        imageArray[i].imageAddress1 = adresse;
                        imageArray[i].imageSize1 = imagesize;
                        imageArray[i].imageType1 = imageType;
                    },
                    2 => {
                        imageArray[i].imageAddress2 = adresse;
                        imageArray[i].imageSize2 = imagesize;
                        imageArray[i].imageType2 = imageType;
                    },
                    3 => {
                        imageArray[i].imageAddress3 = adresse;
                        imageArray[i].imageSize3 = imagesize;
                        imageArray[i].imageType3 = imageType;
                    },
                    else => {},
                }
            }
        }
    }

    return imageArray;
}

/// Caller owns returned memory.
fn readImageFilename(allocator: std.mem.Allocator, reader: *std.Io.File.Reader) ![]const u8 {
    const namelen = try reader.interface.takeByte();
    const myImageNameData = try reader.interface.take(8);
    return try cp1252.cp1252ToUtf8Alloc(allocator, myImageNameData[0..namelen]);
}

fn readImageDescription(reader: *std.Io.File.Reader, _: u32) !void {
    // const textdesc1
    _ = try reader.interface.takeInt(u32, .little);
    // const textdesclength1
    _ = try reader.interface.takeInt(u32, .little);

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
