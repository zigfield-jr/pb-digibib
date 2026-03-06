const std = @import("std");
const cp1252 = @import("enc/cp1252.zig");
const vlado = @import("enc/vlado.zig");
const dbis = @import("DBImageSet.zig");
const writer = @import("writer/PageWriter.zig");
// const writer = @import("writer/StubWriter.zig");

pub const DBPage = struct {
    textpagenumber: i32 = undefined,
    lastpagenumber: i32 = undefined,
    atomCount: i64 = undefined,
    wordCount: i64 = undefined,
    hexaddress: u64 = undefined,
    pageBlock: []u8 = undefined,

    pub fn deinit(self: *DBPage) void {
        std.heap.c_allocator.free(self.pageBlock);
    }

    pub fn parsePageWithFontSize(self: *DBPage, _sucheaktiv: bool, imageDict: std.StringHashMap(dbis.DBImageSet)) !void {
        writer.reset();
        writer.pager(self.textpagenumber, self.lastpagenumber);

        var bold: bool = false;
        var italic: bool = false;
        var gesperrt: bool = false;
        var superscript: bool = false;
        var subscript: bool = false;
        var linkrangebegin: bool = false;
        var urllinkrangebegin: bool = false;
        var underline: bool = false;
        var align_center: bool = false;
        var align_right: bool = false;

        var atFont: i32 = 0;
        var fontsize: f32 = 1.0;
        var farbe: i32 = 0;
        // var link2: u32 = 0;

        var atVorWord: bool = false;
        var hyphen: bool = false;
        var hyphen2: bool = false;
        var hyphenck: bool = false;

        var len: u8 = 0;
        var _len: usize = 0;

        var num_tokens: i32 = 0;
        var oldtoken: i32 = -9999;
        var data: []u8 = self.pageBlock;
        var page_end: bool = false;
        var i: usize = 0;

        while (!page_end) {
            len = 0;
            num_tokens += 1;

            if (num_tokens >= 20000) {
                std.debug.print("mehr als 20000 token, wir brechen ab!\n", .{});
                break;
            }

            const token = data[i];
            // std.debug.print("index: {d} -> token: 0x{x}\n", .{ i, token });
            i += 1;

            switch (token) {
                0 => { // atBlanks
                    const number_of_spaces: usize = data[i];
                    i += 1;

                    const alot_of_spaces = try std.heap.c_allocator.alloc(u8, number_of_spaces);
                    defer std.heap.c_allocator.free(alot_of_spaces);

                    for (alot_of_spaces, 0..) |_, index| {
                        alot_of_spaces[index] = ' ';
                    }
                    writer.write(alot_of_spaces, true, bold, italic or gesperrt, superscript, subscript, linkrangebegin, underline or align_right, fontsize, farbe);
                },
                1 => { // atWord
                    len = data[i];
                    i += 1;
                    _len = (len & 0x7f); // _len = (len & ~0x80) wortlaenge
                    if (_len == 1 and atFont != 0) {
                        var codepoint: u21 = undefined;
                        if (atFont == 1) {
                            codepoint = switch (data[i]) {
                                // https://en.wikipedia.org/wiki/Wingdings
                                0x26 => 0x25eb, // book
                                0x33 => 0x25a4, // page
                                0x41 => 0x2228, // victory
                                0x46 => 0x21f0, // pointer right
                                0xa4 => 0x2299, // image link
                                0xb6 => 0x229b, // page link
                                0xf0 => 0x21e8, // arrow right
                                else => data[i],
                            };
                        } else if (atFont == 2) {
                            codepoint = switch (data[i]) {
                                // https://en.wikipedia.org/wiki/Symbol_(typeface)
                                0x2d => 0x2212, // minus
                                0xc8 => 0x222a, // union
                                else => data[i],
                            };
                        } else {
                            codepoint = data[i];
                        }
                        var utf8_char: [4]u8 = undefined;
                        const utf8_char_length = try std.unicode.utf8Encode(codepoint, &utf8_char);
                        writer.write(utf8_char[0..utf8_char_length], false, bold, italic or gesperrt, superscript, subscript, linkrangebegin, underline or align_right, fontsize, farbe);
                    } else {
                        var unicode = false;
                        for (data[i .. i + _len - 1]) |b| {
                            if (b < 0x20) // Es ist mindestens dezimal 20 (das ist bewiesen!)
                            {
                                unicode = true;
                                break;
                            }
                        }

                        if (unicode) {
                            var offset: usize = i;
                            var utf16_string_length: usize = 0;

                            const utf16_string = try std.heap.c_allocator.alloc(u16, _len);
                            defer std.heap.c_allocator.free(utf16_string);

                            while (data[offset] < 0x20 and offset < i + _len - 1 or data[offset] >= 0x20 and offset < i + _len) {
                                if (data[offset] < 0x20) {
                                    const b1: u16 = data[offset];
                                    const b2: u16 = data[offset + 1];
                                    const c = (b2 * 256) + b1;
                                    utf16_string[utf16_string_length] = vlado.toCodepoint(c);
                                    utf16_string_length += 1;

                                    offset += 1;
                                } else {
                                    utf16_string[utf16_string_length] = cp1252.toCodepoint(data[offset]);
                                    utf16_string_length += 1;
                                }

                                offset += 1;
                            }

                            if (utf16_string_length > 0) {
                                const utf8_string = try std.unicode.utf16LeToUtf8Alloc(std.heap.c_allocator, utf16_string[0..utf16_string_length]);
                                defer std.heap.c_allocator.free(utf8_string);

                                writer.write(utf8_string, false, bold, italic or gesperrt, superscript, subscript, linkrangebegin, underline or align_right, fontsize, farbe);
                            }
                        } // end if unicode == true
                        else // kein unicode enthalten
                        {
                            if (_len > 0) {
                                const utf8_string = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, data[i .. i + _len]);
                                defer std.heap.c_allocator.free(utf8_string);

                                writer.write(utf8_string, false, bold, italic or gesperrt, superscript, subscript, linkrangebegin, underline or align_right, fontsize, farbe);
                            }
                        }
                    }

                    hyphen = false;
                    hyphen2 = false;
                    hyphenck = false;

                    if (len > 0x80) //    heisst blank am ende
                    {
                        len -= 0x80;
                        num_tokens += 1;
                        var space_char = [_]u8{' '};
                        writer.write(&space_char, true, bold, italic or gesperrt, superscript, subscript, linkrangebegin, underline or align_right, fontsize, farbe);
                    }
                },
                2 => { // atHardCRNew
                    writer.cr(fontsize);
                },
                3 => { // atEndOfPage
                    page_end = true;
                },
                4 => { // atKursivAn
                    italic = true;
                },
                5 => { // atKursivAus
                    italic = false;
                },
                6 => { // atFettAn
                    bold = true;
                },
                7 => { // atFettAus
                    bold = false;
                },
                8 => { // atU (Überschrift)
                    const value = data[i];
                    i += 1;
                    if (!_sucheaktiv) {
                        switch (value) {
                            0 => {
                                fontsize = 1.0;
                                bold = false;
                                italic = false;
                            },
                            1 => {
                                fontsize = 1.34;
                            },
                            2 => {
                                fontsize = 1.22;
                            },
                            3 => {
                                fontsize = 1.10;
                            },
                            4 => {
                                fontsize = 1.0;
                                bold = true;
                            },
                            5 => {
                                fontsize = 1.0;
                            },
                            6 => {
                                fontsize = 1.0;
                                italic = true;
                            },
                            else => {
                                fontsize = 1.0;
                                std.debug.print("atU {d} is unknown\n", .{value});
                            },
                        }
                    }
                },
                9 => { // atLy
                },
                10 => { // atImage
                    const b1: u16 = data[i];
                    const b2: u16 = data[i + 1];
                    var width: f32 = @floatFromInt((b2 * 256) + b1);
                    width /= 1000.0;
                    // finalwidth *= 0.85;
                    i += 4;
                    len = data[i];
                    i += 1;

                    if (!_sucheaktiv) {
                        var utf8_string = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, data[i .. i + len]);
                        defer std.heap.c_allocator.free(utf8_string);

                        if (std.mem.findLast(u8, utf8_string, ".")) |index| {
                            utf8_string = utf8_string[0..index];
                        }

                        var write_image = true;
                        if (imageDict.get(utf8_string)) |imageSet| {
                            var imageSet2 = imageSet;

                            const rawImage = imageSet2.rawImage2(std.heap.c_allocator) catch {
                                write_image = false;
                                return undefined;
                            };
                            defer std.heap.c_allocator.free(rawImage);

                            if (write_image) {
                                writer.image(width, rawImage);
                            }
                        } else {
                            write_image = false;
                        }
                    }
                },
                11 => { // atLink
                    len = data[i];
                    i += 1;

                    // const link = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, data[i .. i + len]);
                    // defer std.heap.c_allocator.free(link);
                    // FIXME write link to atlink

                    linkrangebegin = true;
                },
                12 => { // atELink
                    // FIXME implement
                    //                 myRange = NSMakeRange(linkrangebegin,[backString length]-linkrangebegin);
                    //
                    //                 if (link2)
                    //                 {
                    //                     //std.debug.print("link2: %d",link2);
                    //                     [backString addAttribute:NSLinkAttributeName value:[NSNumber numberWithInt:link2] range:myRange];
                    //                     [backString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:myRange];
                    //                 }
                    //                 else if (tempImageSet)
                    //                 {
                    //                     std.debug.print("imageName: %@",[tempImageSet imageName]);
                    //                     [backString addAttribute:NSLinkAttributeName value:tempImageSet range:myRange];
                    //                     [backString addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:myRange];
                    //                 }
                    //                 else if (autolink)
                    //                 {
                    //                     //std.debug.print("autolink: %d",autolink);
                    //                     [backString addAttribute:NSLinkAttributeName value:[NSNumber numberWithInt:autolink] range:myRange];
                    //                     [backString addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:myRange];
                    //                 }
                    //                 else if (atlink)
                    //                 {
                    //                     //std.debug.print("atlink: %@",atlink);
                    //                     NSString* tmpstring = [atlink stringByDeletingPathExtension];
                    //                     id tmpobject = [[band imageDict] objectForKey:tmpstring];
                    //
                    //                     if (tmpobject)
                    //                     {
                    //                         [backString addAttribute:NSLinkAttributeName value:tmpobject range:myRange];
                    //                         [backString addAttribute:NSForegroundColorAttributeName value:[NSColor redColor] range:myRange];
                    //                     }
                    //                 }
                    //
                    //                 tempImageSet = nil;
                    linkrangebegin = false;
                    //                 link2 = 0;
                    //                 autolink = 0;
                    //                 atlink = nil;
                },
                13 => { // atFont
                    atFont = data[i];
                    i += 1;
                },
                14 => { // atFileName
                    len = data[i];
                    i += 1;
                    // const file_name = data[i .. i + len]; // encoding:NSWindowsCP1252StringEncoding
                },
                15 => { // atKonkor
                    // const b1: u16 = data[i];
                    // const b2: u16 = data[i + 1];
                    // const konkordanznumber = (b2 * 256) + b1;
                    i += 2;
                },
                16 => { // atNodeNumber
                    // if (nodenumber == 0) {
                    // const b1: u16 = data[i];
                    // const b2: u16 = data[i + 1];
                    // nodenumber = ((b2 * 256) + b1) + 1;
                    // }
                    i += 2;
                },
                17 => { // atHochAn
                    if (!_sucheaktiv) {
                        superscript = true;
                        subscript = false;
                    }
                },
                18 => { // atHochAus
                    if (!_sucheaktiv) {
                        superscript = false;
                    }
                },
                19 => { // atSigel
                    len = data[i];
                    i += 1;
                    if (len > 0) {
                        // const utf8_string = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, data[i .. i + len]);
                        // defer std.heap.c_allocator.free(utf8_string);
                        // writer.siglum(utf8_string);
                    }
                },
                20 => { // atHeader {wird nicht mehr generiert - wurde es jemals?}
                },
                21 => { // atHyphen
                    hyphen = true;
                },
                22 => { // atGesperrtAn {ACHTUNG: das ist underline !!!}
                    underline = true;
                },
                23 => { // atGesperrtAus {ACHTUNG: das ist underline aus !!!}
                    underline = false;
                },
                24 => { // atGriechischAn
                },
                25 => { // atGriechischAus
                },
                27 => { // atOneBlank
                    var space_char = [_]u8{' '};
                    writer.write(&space_char, true, bold, italic or gesperrt, superscript, subscript, linkrangebegin, underline or align_right, fontsize, farbe);
                },
                28 => { // atLinieAn
                },
                29 => { // atLinieAus
                },
                30 => { // atTD
                },
                31 => { // atNil
                },
                128 => { // atLink2 {ersetzt atLink}
                    // const b1: u32 = data[i];
                    // const b2: u32 = data[i + 1];
                    // const b3: u32 = data[i + 2];
                    // link2 = (b3 * 256 * 256) + (b2 * 256) + b1;
                    i += 4;
                    len = data[i];
                    i += 1;
                    if (!_sucheaktiv) {
                        linkrangebegin = true;
                        //     if (link2 == 0) { // FIXME link to image
                        //         const temp_string = data[i .. i + len]; // encoding:NSWindowsCP1252StringEncoding
                        //         tempImageSet = [[band imageDict] objectForKey:[[temp_string stringByDeletingPathExtension] lowercaseString]];
                        //     }
                    }
                },
                129 => { // atID
                    i += 1;
                },
                130 => { // atEID
                    i += 1;
                },
                131 => { // atTiefAn
                    if (!_sucheaktiv) {
                        subscript = true;
                        superscript = false;
                    }
                },
                132 => { // atTiefAus
                    if (!_sucheaktiv) {
                        subscript = false;
                    }
                },
                133 => { // atFarbe
                    const palette: u8 = data[i];
                    i += 1;

                    farbe = 0;
                    if (palette > 0 and palette < 9) {
                        const mask1: i32 = 0xaa;
                        const shift1: u5 = @intCast(@divTrunc(palette, 3) * 8);
                        farbe |= (mask1 << shift1);

                        const mask2: i32 = 0xff;
                        const shift2: u5 = @intCast((palette % 3) * 8);
                        farbe |= (mask2 << shift2);
                    }
                },
                134 => { // atBildFliess
                    // const b1: u16 = data[i];
                    // const b2: u16 = data[i + 1];
                    // const mywidth = (b2 * 256) + b1;
                    i += 2;
                    // const c1: u16 = data[i];
                    // const c2: u16 = data[i + 1];
                    // const myheight = (c2 * 256) + c1;
                    i += 2;
                    len = data[i];
                    i += 1;

                    if (!_sucheaktiv) {
                        var utf8_string = try cp1252.cp1252ToUtf8Alloc(std.heap.c_allocator, data[i .. i + len]);
                        defer std.heap.c_allocator.free(utf8_string);

                        if (std.mem.findLast(u8, utf8_string, ".")) |index| {
                            utf8_string = utf8_string[0..index];
                        }

                        var write_image = true;
                        if (imageDict.get(utf8_string)) |imageSet| {
                            var imageSet2 = imageSet;

                            const rawImage = imageSet2.rawImage1(std.heap.c_allocator) catch {
                                write_image = false;
                                return undefined;
                            };
                            defer std.heap.c_allocator.free(rawImage);

                            if (write_image) {
                                writer.imageInline(fontsize, rawImage);
                            }
                        } else {
                            write_image = false;
                        }

                        if (!write_image) {
                            var utf8_char: [4]u8 = undefined;
                            const utf8_char_length = try std.unicode.utf8Encode(0xfffc, &utf8_char);
                            writer.write(utf8_char[0..utf8_char_length], false, bold, italic or gesperrt, superscript, subscript, linkrangebegin, underline or align_right, fontsize, farbe);
                        }
                    }
                },
                135 => { // atSuchWord
                    len = data[i];
                    i += 1;
                    //                 temp_data = [NSData dataWithBytes:&data[i] length:len];
                    //                 temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
                    //                 [self addToWordList:temp_string Range:NSMakeRange(0,0) AllowSplit:NO];
                },
                136 => { // atSG (Schriftgröße)
                    fontsize = @floatFromInt(data[i]);
                    fontsize /= 100.0;
                    i += 1;
                },
                137 => { // atCopyRight
                    i += 1;
                },
                138 => { // atAutoLink
                    linkrangebegin = true;
                    // autolink = (data[i+2]*256*256)+(data[i+1]*256)+data[i];
                    i += 4;
                },
                139 => { // atSoftCRNew
                    writer.cr(fontsize);
                },
                140 => { // atHyphen2
                    hyphen2 = true;
                },
                141 => { // atNewGesperrt
                    gesperrt = true;
                },
                142 => { // atENewGesperrt
                    gesperrt = false;
                },
                143 => { // atHZA (halber Zeilenabstand)
                    if (!_sucheaktiv) {
                        writer.cr(fontsize / 2);
                    }
                },
                144 => { // atLI
                },
                145 => { // atELI
                },
                146 => { // atUL
                },
                147 => { // atEUL
                },
                148 => { // atSetX {offset linker rand pixel}
                    const b1: u16 = data[i];
                    const b2: u16 = data[i + 1];
                    var xvalue: f32 = @floatFromInt((b2 * 256) + b1);
                    xvalue /= 1000.0;
                    i += 2;

                    if (xvalue > 0) {
                        writer.setX(xvalue);
                    }
                },
                149 => { // atSV
                    i += 8;
                },
                150 => { // atSVStichwort
                    len = data[i];
                    i += 1;
                    //                 temp_data = [NSData dataWithBytes:&data[i] length:len];
                    //                 temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
                },
                151 => { // atKeinSVFF
                },
                152 => { // atZentriert
                    align_center = true;
                },
                153 => { // atZentriertEnde
                    align_center = false;
                },
                154 => { // atR
                    align_right = true;
                },
                155 => { // atER
                    align_right = false;
                },
                156 => { // atE {wird nicht mehr verwendet!!!}
                    i += 2;
                },
                157 => { // atEE
                },
                158 => { // atBiblioPageNr
                    i += 4;
                },
                159 => { // atNotFirstLine
                },
                160 => { // atThumbXXX
                },
                161 => { // atENew
                    i += 3;
                },
                162 => { // atURL
                    len = data[i];
                    i += 1;

                    // [atURL release];
                    // atURL = null;

                    urllinkrangebegin = true;

                    //                 if (len > 0)
                    //                 {
                    //                     temp_data = [NSData dataWithBytes:&data[i] length:len];
                    //                     if ([temp_data length] > 0)
                    //                         atURL = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
                    //                 }
                },
                163 => { // atEURL
                    urllinkrangebegin = false;
                    //
                    //                 [backString addAttribute:NSLinkAttributeName value:atURL range:myRange];
                    //                 [backString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:myRange];
                    //
                    linkrangebegin = false;
                    //                 link2 = 0;
                    //                 autolink = 0;
                    //                 [atURL release];
                    //                 atURL = nil;
                    //
                },
                164 => { // atWortAnker
                },
                165 => { // atThumbWWW
                },
                166 => { // atS
                },
                167 => { // atKeinBlocksatzAn
                },
                168 => { // atKeinBlocksatzAus
                },
                169 => { // atNextBlankIsFixed
                },
                170 => { // atRestWord
                    len = data[i];
                    i += 1;
                    if (len > 0x80) { // heisst blank am ende
                        len -= 0x80;
                        // num_tokens++;
                        // std.debug.print("Achtung, numtokens wurde manuell erhoeht!\n", .{});
                    }
                    //                 temp_data = [NSData dataWithBytes:&data[i] length:len];
                    //                 temp_string = [[NSString alloc] initWithData:temp_data encoding:NSWindowsCP1252StringEncoding];
                    //
                    //                                 [self generateWordList:&data[i] Length:len Range:NSMakeRange([backString length],len) Hyphen:hyphen||hyphen2||hyphenck  Font:atFont];
                    //
                    // //                [self addToWordList:[word stringByAppendingString:temp_string] Range:r AllowSplit:YES];
                },
                171 => { // atVorWord
                    len = data[i];
                    i += 1;
                    atVorWord = true;
                    // const temp_string = data[i .. i + len]; // encoding:NSWindowsCP1252StringEncoding
                },
                172 => { // atHyphenCK
                    hyphenck = true;
                },
                173 => { // atHebrAn
                },
                174 => { // atHebrAus
                },
                175 => { // atNodeNumber2
                    //                 if (nodenumber == 0)
                    //                     nodenumber = ((data[i+2]*256*256)+(data[i+1]*256)+data[i]) + 1;
                    i += 4;
                },
                176 => { // atDurchAn
                },
                177 => { // atDurchAus
                },
                178 => { // atSetY
                    i += 2;
                },
                179 => { // atCor
                },
                180 => { // atECor
                },
                else => { // keinen passenden Tag gefunden!
                    std.debug.print("pagenumber: {d}  num_tokens: {d}  pos: {d}  Unknown token: {d}\n", .{ self.textpagenumber, num_tokens, i, data[i - 1] });
                    std.debug.print("token before: {d}\n", .{oldtoken});
                    page_end = true;
                },
            }

            oldtoken = token;

            i += len;
            if (i >= self.pageBlock.len) {
                // std.debug.print("pageblock ende: {d}\n", .{i});
                page_end = true;
            }
        }

        if (!_sucheaktiv) {
            if (i != self.pageBlock.len) {
                std.debug.print("i = {d} size = {d}", .{ i, self.pageBlock.len });
            }
            if (self.atomCount != num_tokens and self.atomCount != 0) {
                std.debug.print("num_tokens = {d} soll_tokens = {d}", .{ num_tokens, self.atomCount });
            }
        }
    }

    pub fn displayPageInView(self: *DBPage, imageDict: std.StringHashMap(dbis.DBImageSet)) !void {
        try self.parsePageWithFontSize(false, imageDict);
    }
};
