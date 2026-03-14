const std = @import("std");
const dbp = @import("DBPage.zig");
const helper = @import("Helper.zig");
const cp1252 = @import("enc/cp1252.zig");
const dbil = @import("DBImageLoader.zig");
const dbis = @import("DBImageSet.zig");
const e = @import("Entry.zig");

pub const Band = struct {

    // StartWindowController

    path: []u8 = undefined,
    name: []u8 = undefined,
    data: []u8 = undefined,
    images: []u8 = undefined,

    digibib_path: []u8 = undefined,
    textDKI_path: []u8 = undefined,
    treeDKI_path: []u8 = undefined,
    treeDKA_path: []u8 = undefined,
    imageLib_path: []u8 = undefined,

    // digigbib.txt

    major: i32 = 0,
    minor: i32 = 0,
    caption: []u8 = undefined,

    // book

    magic: bool = undefined,
    lastpagenumber: u32 = undefined,
    texttab: []u32 = undefined, // blockpointerarray[0]

    //    NSArray *directoryTree;
    tree_array: []const e.Entry = undefined,
    //    int linesInTree;

    imageArray: []dbis.DBImageSet = undefined,
    imageDict: std.StringHashMap(dbis.DBImageSet) = undefined,

    pub fn deinit(self: *Band) void {
        std.heap.c_allocator.free(self.caption);
        std.heap.c_allocator.free(self.texttab);

        for (self.imageArray) |imageSet| {
            var imageSet2 = imageSet;
            imageSet2.deinit();
        }

        self.imageDict.deinit();
    }

    pub fn initWithPath(self: *Band) !void {
        //    NSDictionary* imageLocatorDict;
        //    // if (imageLocatorDict == nil)
        //    // {
        //    // NSLog(@"Error: ImageLocator File nicht gefunden!");
        //    // }

        //    blockpointerarray[0] = 0;
        //    blockpointerarray[1] = 0;
        //    blockpointerarray[2] = 0;
        //    blockpointerarray[3] = 0;
        //    blockpointerarray[4] = 0;

        //    NSLog(@"masterpath: %@",masterPath);

        //    TreeDKI_path = [Helper findFile:@"Data/Tree.dki" startPath:masterPath];
        //    TreeDKA_path = [Helper findFile:@"Data/TREE.DKA" startPath:masterPath];
        //    TextDKI_path = [Helper findFile:@"Data/TEXT.DKI" startPath:masterPath];
        //    Digibib_path = [Helper findFile:@"DATA/DIGIBIB.TXT" startPath:masterPath];

        //    if ([[NSFileManager defaultManager] isReadableFileAtPath:TextDKI_path] == NO)
        //    {
        //    NSLog (@"%@: file not readable",TextDKI_path);
        //    // hier sollte nun abgebrochen werden !
        //    // am besten nen Alert
        //    }

        //    // NSLog(@"imageLocatordictArray: %@",[imageLocatorDict objectForKey:key]);
        // imageLocatorArray = [[imageLocatorDict objectForKey:majorString] retain];

        try self.loadTextTable();

        try self.loadTreeTable();

        self.imageDict = .init(std.heap.c_allocator);
        if (self.imageLib_path.len != 0) {
            self.imageArray = try dbil.loadImageTable(std.heap.c_allocator, self.path, self.name, self.images, self.imageLib_path);
            for (self.imageArray) |imageSet| {
                try self.imageDict.put(imageSet.image_filename, imageSet);
            }
        } else {
            self.imageArray = try std.heap.c_allocator.alloc(dbis.DBImageSet, 0);
        }
    }

    /// Caller owns returned memory.
    pub fn loadCoverImage(self: *Band, allocator: std.mem.Allocator) ![]const u8 {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        var coverfile_buffer: [20]u8 = undefined;
        var coverfile_name: []u8 = undefined;
        if (self.major < 0) {
            coverfile_name = try std.fmt.bufPrint(&coverfile_buffer, "COVERm{d}.BMP", .{@abs(self.major)});
        } else {
            coverfile_name = try std.fmt.bufPrint(&coverfile_buffer, "COVER{d}.BMP", .{self.major});
        }

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data });
        defer std.heap.c_allocator.free(absolute_path);

        var data = try std.Io.Dir.openDirAbsolute(io, absolute_path, .{ .iterate = true });
        defer data.close(io);

        var iter = data.iterate();
        while (try iter.next(io)) |entry| {
            switch (entry.kind) {
                .file => {
                    if (std.ascii.eqlIgnoreCase(entry.name, coverfile_name)) {
                        return try allocator.dupe(u8, entry.name);
                    }
                },
                else => {},
            }
        }

        return std.Io.Dir.OpenError.FileNotFound;
    }

    pub fn loadDigibibTable(self: *Band) !void {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data, self.digibib_path });
        defer std.heap.c_allocator.free(absolute_path);

        const ini_file = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer ini_file.close(io);

        var ini_buffer: [1024]u8 = undefined;
        var ini_reader = ini_file.reader(io, &ini_buffer);

        var default_group: bool = false;
        while (try ini_reader.interface.takeDelimiter('\n')) |s| {
            const line = std.mem.trimEnd(u8, s, "\r");
            var iter = std.mem.splitScalar(u8, line, '=');
            if (iter.next()) |first| {
                if (iter.next()) |second| { // key value pair
                    if (default_group and std.mem.eql(u8, first, "CDMajor")) {
                        self.major = try std.fmt.parseInt(i32, second, 10);
                    }
                    if (default_group and std.mem.eql(u8, first, "CDMinor")) {
                        self.minor = try std.fmt.parseInt(i32, second, 10);
                    }
                    if (default_group and std.mem.eql(u8, first, "Caption")) {
                        const caption_utf8 = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, second);
                        defer std.heap.c_allocator.free(caption_utf8);

                        self.caption = try std.mem.replaceOwned(u8, std.heap.c_allocator, caption_utf8, ": ", ":\n");
                    }
                } else {
                    default_group = std.mem.eql(u8, first, "[Default]");
                }
            }
        }
    }

    /// checks if text.dki is readable and reads pagecount (lastpagenumber)
    fn loadTextTable(self: *Band) !void {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data, self.textDKI_path });
        defer std.heap.c_allocator.free(absolute_path);

        const text_file = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer text_file.close(io);

        var text_buffer: [1024]u8 = undefined;
        var text_reader = text_file.reader(io, &text_buffer);
        self.magic = try helper.isMagic(&text_reader);
        if (!self.magic) {
            _ = try text_reader.seekTo(0);
        } else {
            _ = try text_reader.interface.takeInt(u32, .little);
        }

        // read some bytes from the TOC of the text.dki file
        self.texttab = try readblock(std.heap.c_allocator, 4, &text_reader);
        self.lastpagenumber = @intCast(self.texttab.len);
        self.lastpagenumber -= 1;
    }

    pub fn textPageData(self: *Band, textpagenumber: u32) !dbp.DBPage {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        if (self.texttab.len == 0) {
            std.debug.print("Text table is not initialized!\n", .{});
        }

        const page_address: u64 = self.texttab[@intCast(textpagenumber - 1)];

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data, self.textDKI_path });
        defer std.heap.c_allocator.free(absolute_path);

        const text_file = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer text_file.close(io);

        var text_buffer: [1024]u8 = undefined;
        var text_reader = text_file.reader(io, &text_buffer);
        _ = try text_reader.seekTo(page_address);

        var page_size: u16 = try text_reader.interface.takeInt(u16, .little);
        var atom_count: u16 = 0;
        var word_count: u16 = 0;
        if (self.magic) {
            atom_count = try text_reader.interface.takeInt(u16, .little);
            word_count = try text_reader.interface.takeInt(u16, .little);
        } else {
            page_size -= 2;
        }

        const page_block = try text_reader.interface.readAlloc(std.heap.c_allocator, page_size);

        return dbp.DBPage{
            .page_block = page_block,
            .textpagenumber = textpagenumber,
            .lastpagenumber = self.lastpagenumber,
            .atom_count = atom_count,
            .word_count = word_count,
            .hexaddress = page_address,
        };
    }

    fn loadTreeTable(self: *Band) !void {
        var tree_array = try self.initializeTree(std.heap.c_allocator);

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data, self.treeDKA_path });
        defer std.heap.c_allocator.free(absolute_path);

        const tree_file = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer tree_file.close(io);

        var tree_buffer: [1024]u8 = undefined;
        var tree_reader = tree_file.reader(io, &tree_buffer);

        const treetablecountersize: u8 = if (tree_array.len > std.math.maxInt(u16)) 4 else 2;

        _ = try readblock(std.heap.c_allocator, treetablecountersize, &tree_reader);
        _ = try readblock(std.heap.c_allocator, treetablecountersize, &tree_reader);
        _ = try readblock(std.heap.c_allocator, treetablecountersize, &tree_reader);
        const tree_table = try readblock(std.heap.c_allocator, treetablecountersize, &tree_reader);

        if (tree_array.len == tree_table.len) {
            for (tree_array, 0..) |_, i| {
                tree_array[i].textpagenumber = tree_table[i];
            }
            self.tree_array = tree_array;
        } else {
            self.tree_array = try std.heap.c_allocator.alloc(e.Entry, 0);
        }
    }

    /// Caller owns returned memory.
    fn readblock(allocator: std.mem.Allocator, countersize: u8, reader: *std.Io.File.Reader) ![]u32 {
        var pointercounter: u32 = 1; // this is lastpagenumber + 1

        if (countersize == 2) { // zwei byte zeiger < 64k Seiten
            pointercounter += try reader.interface.takeInt(u16, .little);
        } else if (countersize == 4) { // vier byte zeiger > 64k Seiten
            pointercounter += try reader.interface.takeInt(u32, .little);
        } else {
            return ReadBlockError.PointercounterNotTwoOrFour;
        }

        var block = try allocator.alloc(u32, @intCast(pointercounter));
        for (0..@intCast(pointercounter)) |i| {
            block[i] = try reader.interface.takeInt(u32, .little);
        }

        return block;
    }

    fn initializeTree(self: *Band, allocator: std.mem.Allocator) ![]e.Entry {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data, self.treeDKI_path });
        defer std.heap.c_allocator.free(absolute_path);

        const tree_file = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer tree_file.close(io);

        var tree_buffer: [1024]u8 = undefined;
        var tree_reader = tree_file.reader(io, &tree_buffer);

        var tree_list: std.ArrayList(e.Entry) = .empty;
        defer tree_list.deinit(std.heap.c_allocator);

        var linenumber: u32 = 1;
        while (try tree_reader.interface.takeDelimiter('\n')) |line| {
            linenumber += 1;
            const line_trim = std.mem.trimStart(u8, line, " ");
            const linelevel: u8 = @intCast(line.len - line_trim.len);
            try tree_list.append(std.heap.c_allocator, e.Entry{
                .name = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, line_trim),
                .level = linelevel,
                .link_number = linenumber,
            });
        }

        return try tree_list.toOwnedSlice(allocator);
    }
};

const ReadBlockError = error{PointercounterNotTwoOrFour};
