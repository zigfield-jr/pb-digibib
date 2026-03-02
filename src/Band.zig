const std = @import("std");
const dbp = @import("DBPage.zig");
const helper = @import("Helper.zig");
const cp1252 = @import("enc/cp1252.zig");

pub const Band = struct {

    // StartWindowController

    path: []u8 = undefined,
    name: []u8 = undefined,
    data: []u8 = undefined,
    digibib_path: []u8 = undefined,
    textDKI_path: []u8 = undefined,
    //    NSString* treeDKI_path;
    //    NSString* treeDKA_path;

    // digigbib.txt

    major: i32 = 0,
    minor: i32 = 0,
    caption: []u8 = undefined,

    // book

    magic: bool = undefined,
    lastpagenumber: i32 = undefined,
    texttab: []u32 = undefined, // blockpointerarray[0]
    // var treetab : []u32 = undefined; // blockpointerarray[4]

    //    NSArray *directoryTree;
    //    NSMutableArray* treeArray;
    //    int linesInTree;
    //
    //    NSMutableDictionary* imageDict;  // alle Bilder auch die hidden
    //    NSMutableArray* imageArray;   // nur die bilder welche nicht hidden sind!
    //    NSMutableArray* hiddenImageArray;
    //    NSArray *imageLocatorArray;
    //    int totalImages;
    //    BOOL imageMagic;

    pub fn deinit(self: *Band) void {
        std.heap.c_allocator.free(self.caption);
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

        //    [self loadTreeTable];
        //    [DBImageLoader loadImageTable:self];
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

        const file = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer file.close(io);

        var file_buffer: [1024]u8 = undefined;
        var file_reader = file.reader(io, &file_buffer);

        var default_group: bool = false;
        while (try file_reader.interface.takeDelimiter('\n')) |s| {
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
                        const caption_encoded = try std.heap.c_allocator.dupe(u8, second);
                        defer std.heap.c_allocator.free(caption_encoded);

                        self.caption = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, caption_encoded);
                    }
                } else {
                    default_group = std.mem.eql(u8, first, "[Default]");
                }
            }
        } else {}
    }

    /// checks if text.dki is readable and reads pagecount (lastpagenumber)
    pub fn loadTextTable(self: *Band) !void {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data, self.textDKI_path });
        defer std.heap.c_allocator.free(absolute_path);

        const textdkihandle = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer textdkihandle.close(io);

        var file_buffer: [1024]u8 = undefined;
        var file_reader = textdkihandle.reader(io, &file_buffer);
        self.magic = try helper.isMagic(&file_reader);
        if (!self.magic) {
            _ = try file_reader.seekTo(0);
        } else {
            _ = try file_reader.interface.takeInt(u32, .little);
        }

        // read some bytes from the TOC of the text.dki file
        self.texttab = try readblock(4, &file_reader);
        self.lastpagenumber = @intCast(self.texttab.len);
        self.lastpagenumber -= 1;
    }

    pub fn textPageData(self: *Band, _seite: i32) !dbp.DBPage {
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();

        var atomCount: i64 = 0;
        var wordCount: i64 = 0;

        var pageAddress: u64 = 0;

        if (
        // treetab == 0 ||
        self.texttab.len == 0) {
            std.debug.print("Text- and/or TreeTable is not initialized!\n", .{});
        }

        pageAddress = (self.texttab[@intCast(_seite - 1)]);

        const absolute_path = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ self.path, self.name, self.data, self.textDKI_path });
        defer std.heap.c_allocator.free(absolute_path);

        const textdkihandle = try std.Io.Dir.openFileAbsolute(io, absolute_path, .{ .mode = .read_only });
        defer textdkihandle.close(io);

        var file_buffer: [4096]u8 = undefined;
        var file_reader = textdkihandle.reader(io, &file_buffer);
        _ = try file_reader.seekTo(pageAddress);

        var pagesize = try file_reader.interface.takeInt(u16, .little);

        if (self.magic) {
            atomCount = try file_reader.interface.takeInt(u16, .little);
            wordCount = try file_reader.interface.takeInt(u16, .little);
        } else {
            pagesize -= 2;
        }

        const mem = try file_reader.interface.take(pagesize);

        return dbp.DBPage{
            .pageBlock = try std.heap.c_allocator.dupe(u8, mem),
            .textpagenumber = _seite,
            .lastpagenumber = self.lastpagenumber,
            .atomCount = atomCount,
            .wordCount = wordCount,
            .hexaddress = pageAddress,
        };
    }

    //    -(int) loadTreeTable
    //    {
    //    FILE *fh = 0;
    //
    //    int treetablecountersize;
    //
    //    unsigned short wordcounter;
    //
    //    // erstmal die TreeLines laden damit wir die pointersize wissen!
    //
    //    NSLog(@"initialize Tree Array");
    //    NSArray* temp_tree_array = [self initializeTree];
    //
    //    //    NSString* filename = TreeDKA_path;
    //
    //    NSFileHandle* myNSFileHandle = [NSFileHandle fileHandleForReadingAtPath:TreeDKA_path];
    //    fh = fdopen([myNSFileHandle fileDescriptor],"r");
    //
    //    //    fh = fopen([filename cString],"r");
    // if (fh == 0) NSLog (@"file open error!");
    //
    //    //    stat([filename cString],&sb);
    //    //    NSLog(@"Size in Bytes : %qd",sb.st_size);
    //
    //    treetablecountersize = 2;
    //    if ([temp_tree_array count] > 65535) treetablecountersize = 4;
    //
    //    //    NSLog (@"treetablecountersize: %d",treetablecountersize);
    //
    //    wordcounter = readblock(treetablecountersize,fh,1,blockpointerarray);
    //    wordcounter = readblock(treetablecountersize,fh,2,blockpointerarray);
    //    wordcounter = readblock(treetablecountersize,fh,3,blockpointerarray);
    //    wordcounter = readblock(treetablecountersize,fh,4,blockpointerarray);
    //
    //    fclose (fh);
    //
    //    [myNSFileHandle closeFile];
    //
    //    return 0;
    //    }

    /// Caller owns returned memory.
    fn readblock(countersize: u8, reader: *std.Io.File.Reader) ![]u32 {
        var pointercounter: u32 = 1; // this is lastpagenumber + 1

        if (countersize == 2) { // zwei byte zeiger < 64k Seiten
            pointercounter += try reader.interface.takeInt(u16, .little);
        } else if (countersize == 4) { // vier byte zeiger > 64k Seiten
            pointercounter += try reader.interface.takeInt(u32, .little);
        } else {
            return ReadBlockError.PointercounterNotTwoOrFour;
        }

        var block = try std.heap.c_allocator.alloc(u32, @intCast(pointercounter));
        for (0..@intCast(pointercounter)) |i| {
            block[i] = try reader.interface.takeInt(u32, .little);
        }

        return block;
    }
};

const ReadBlockError = error{PointercounterNotTwoOrFour};

// -(NSArray*)initializeTree;
// {
//     int lastlevel = 0;
//     int linelevel = 1;
//     int linenumber = 1;
//     int n;
//
//     NSEnumerator *enu;
//     NSString* line;
//
//     Entry* parent = 0;
//     Entry* myEntry;
//
//     NSLog(@"initializing TreeTable");
//
//     NSData *myData = [NSData dataWithContentsOfFile: TreeDKI_path];
//     NSString* temp_string = [[NSString alloc] initWithData:myData encoding:NSWindowsCP1252StringEncoding];
//
//     NSArray* temp_tree_array = [temp_string componentsSeparatedByString:@"\n"];
//     [temp_string release];
//
//     if ([temp_tree_array count] > 0)
//     {
//         treeArray = [[NSMutableArray alloc] initWithCapacity:[temp_tree_array count]];
//
//         enu = [temp_tree_array objectEnumerator];
//         line = [enu nextObject];
//
//         myEntry = [[Entry alloc] initWithName:line level:linelevel linkNumber:23232323 band:self treeArrayIndex:[treeArray count]];
//
//         [treeArray addObject:myEntry];
//         [treeArray addObject:myEntry];
//
//         parent = myEntry;
//
//         while (line = [enu nextObject])
//         {
//             if ([line length] == 0)
//                 continue;
//
//             linenumber++;
//
//             for (linelevel = 0 ; [line characterAtIndex:linelevel] == ' ' ; linelevel++);
//
//             if (linelevel > lastlevel)
//             {
//                 parent = [parent lastChild] != nil ? [parent lastChild] : parent;
//             }
//             else if (linelevel < lastlevel)
//             {
//                 for (n = (lastlevel - linelevel); n > 0 ;n--)
//                 {
// //                    NSLog(@"%d,%d",linelevel,lastlevel);
//                     parent = [parent parent];
//                 }
//             }
//
//             lastlevel = linelevel;
//
//             myEntry = [[Entry alloc] initWithName:line level:linelevel linkNumber:linenumber band:self treeArrayIndex:[treeArray count]];
//
//             [treeArray addObject:myEntry];
//             [parent addChild:myEntry];
//             //NSLog(@"treeentry: %@",myEntry);
//             [myEntry release];
//         }
//     }
//
//     NSLog(@"Lines in Tree.dki: %d",linenumber);
//     return temp_tree_array;
// }
