const std = @import("std");
const b = @import("Band.zig");

pub const Entry = struct {
    name: []u8 = undefined,
    level: u16 = undefined,
    link_number: u32 = undefined,
    textpagenumber: u32 = undefined,
};
