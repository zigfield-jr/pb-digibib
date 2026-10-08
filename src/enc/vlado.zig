const std = @import("std");

pub fn toCodepoint(c1: u5, c2: u8) u16 {
    const b1: u16 = c1;
    const b2: u16 = c2;

    var unizeichen: u16 = undefined;
    unizeichen = b2 -% (b1 + 1);
    unizeichen +%= 256 *% (b1 -% 1);

    if (unizeichen >= 0x0700 and unizeichen < 0x1100) {
        unizeichen += 0x1700;
    } else if (unizeichen >= 0x1100 and unizeichen < 0x1200) {
        unizeichen += (0xe000 - 0x1100);
    }
    if (unizeichen >= 0x1200 and unizeichen < 0x1e00) {
        // std.debug.print("unicode: 0x{x}\n", .{unizeichen});
    }
    return unizeichen;
}

test toCodepoint {
    for (0..32) |i| {
        for (0..256) |j| {
            _ = toCodepoint(@intCast(i), @intCast(j));
        }
    }

    // 0x0000-0x06ff
    // 0x1200-0x27ff
    // 0xe000-0xe0ff
    // 0xfeff-0xffff
}
