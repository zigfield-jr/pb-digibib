const std = @import("std");
const b = @import("Band.zig");

pub const Entry = struct {
    name: []u8,
    level: u16,
    link_number: u32,
    textpagenumber: u32 = undefined,

    pub fn deinit(self: *Entry) void {
        std.heap.c_allocator.free(self.name);
    }
};
