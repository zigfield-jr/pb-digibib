const std = @import("std");

const magic: u32 = 1647820;

pub fn isMagic(reader: *std.Io.File.Reader) !bool {
    _ = try reader.seekTo(0);
    const plxmagic = try reader.interface.takeInt(u32, .little);
    return plxmagic == magic; // magic number
}

test isMagic {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file = try tmp_dir.dir.createFile(io, "Text.dki", .{ .read = true });
    defer file.close(io);

    var r_buffer: [4]u8 = undefined;
    var file_writer: std.Io.File.Writer = .init(file, io, &r_buffer);
    try file_writer.interface.writeAll(&.{ 0xcc, 0x24, 0x19, 0x0 });
    try file_writer.interface.flush();

    var file_reader = file_writer.moveToReader();

    try std.testing.expect(try isMagic(&file_reader));
}
