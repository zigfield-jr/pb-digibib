const std = @import("std");

/// Caller owns returned memory.
pub fn cp1252ToUtf8Alloc(allocator: std.mem.Allocator, cp1252: []const u8) std.unicode.Utf16LeToUtf8AllocError![]u8 {
    const utf16le = try std.heap.c_allocator.alloc(u16, cp1252.len);
    defer std.heap.c_allocator.free(utf16le);

    for (cp1252, 0..) |c, i| {
        utf16le[i] = toCodepoint(c);
    }
    return try std.unicode.utf16LeToUtf8Alloc(allocator, utf16le);
}

pub fn toCodepoint(c: u8) u16 {
    return switch (c) {
        // https://en.wikipedia.org/wiki/Windows-1252
        0x80 => 0x20ac,
        0x82 => 0x201a,
        0x83 => 0x0192,
        0x84 => 0x201e,
        0x85 => 0x2026,
        0x86 => 0x2020,
        0x87 => 0x2021,
        0x88 => 0x02c6,
        0x89 => 0x2030,
        0x8a => 0x0160,
        0x8b => 0x2039,
        0x8c => 0x0152,
        0x8e => 0x017d,
        0x91 => 0x2018,
        0x92 => 0x2019,
        0x93 => 0x201c,
        0x94 => 0x201d,
        0x95 => 0x2022,
        0x96 => 0x2013,
        0x97 => 0x2014,
        0x98 => 0x02dc,
        0x99 => 0x2122,
        0x9a => 0x0161,
        0x9b => 0x203a,
        0x9c => 0x0153,
        0x9e => 0x017e,
        0x9f => 0x0178,
        else => c,
    };
}
