const std = @import("std");
const io = std.io;

const cursor = @import("cursor.zig");

const Key = union(enum) {
    // unicode character
    char: u21,
    ctrl: u21,
    alt: u21,
    ctrl_alt: u21,
    fun: u8,

    // arrow keys
    up: void,
    down: void,
    left: void,
    right: void,

    // shift + arrow keys
    shift_up: void,
    shift_down: void,
    shift_left: void,
    shift_right: void,

    // ctrl + arrow keys
    ctrl_up: void,
    ctrl_down: void,
    ctrl_left: void,
    ctrl_right: void,

    // ctrl + shift + arrow keys
    ctrl_shift_up: void,
    ctrl_shift_down: void,
    ctrl_shift_left: void,
    ctrl_shift_right: void,

    // ctrl + alt + arrow keys
    ctrl_alt_up: void,
    ctrl_alt_down: void,
    ctrl_alt_left: void,
    ctrl_alt_right: void,

    // special keys
    esc: void,
    backspace: void,
    delete: void,
    insert: void,
    enter: void,
    page_up: void,
    page_down: void,
    home: void,
    end: void,

    __non_exhaustive: void,

    pub fn format(
        value: Key,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;
        _ = fmt;
        try writer.writeAll("Key.");

        switch (value) {
            .ctrl => |c| try std.fmt.format(writer, "ctrl({u})", .{c}),
            .alt => |c| try std.fmt.format(writer, "alt({u})", .{c}),
            .ctrl_alt => |c| try std.fmt.format(writer, "ctrl_alt({u})", .{c}),
            .char => |c| try std.fmt.format(writer, "char({u})", .{c}),
            .fun => |d| try std.fmt.format(writer, "fun({d})", .{d}),

            // arrow keys
            .up => try std.fmt.format(writer, "up", .{}),
            .down => try std.fmt.format(writer, "down", .{}),
            .left => try std.fmt.format(writer, "left", .{}),
            .right => try std.fmt.format(writer, "right", .{}),

            // shift + arrow keys
            .shift_up => try std.fmt.format(writer, "shift_up", .{}),
            .shift_down => try std.fmt.format(writer, "shift_down", .{}),
            .shift_left => try std.fmt.format(writer, "shift_left", .{}),
            .shift_right => try std.fmt.format(writer, "shift_right", .{}),

            // ctrl + arrow keys
            .ctrl_up => try std.fmt.format(writer, "ctrl_up", .{}),
            .ctrl_down => try std.fmt.format(writer, "ctrl_down", .{}),
            .ctrl_left => try std.fmt.format(writer, "ctrl_left", .{}),
            .ctrl_right => try std.fmt.format(writer, "ctrl_right", .{}),

            // ctrl + shift + arrow keys
            .ctrl_shift_up => try std.fmt.format(writer, "ctrl_shift_up", .{}),
            .ctrl_shift_down => try std.fmt.format(writer, "ctrl_shift_down", .{}),
            .ctrl_shift_left => try std.fmt.format(writer, "ctrl_shift_left", .{}),
            .ctrl_shift_right => try std.fmt.format(writer, "ctrl_shift_right", .{}),

            // ctrl + alt + arrow keys
            .ctrl_alt_up => try std.fmt.format(writer, "ctrl_alt_up", .{}),
            .ctrl_alt_down => try std.fmt.format(writer, "ctrl_alt_down", .{}),
            .ctrl_alt_left => try std.fmt.format(writer, "ctrl_alt_left", .{}),
            .ctrl_alt_right => try std.fmt.format(writer, "ctrl_alt_right", .{}),

            // special keys
            .esc => try std.fmt.format(writer, "esc", .{}),
            .enter => try std.fmt.format(writer, "enter", .{}),
            .backspace => try std.fmt.format(writer, "backspace", .{}),
            .delete => try std.fmt.format(writer, "delete", .{}),
            .insert => try std.fmt.format(writer, "insert", .{}),
            .page_up => try std.fmt.format(writer, "page_up", .{}),
            .page_down => try std.fmt.format(writer, "page_down", .{}),
            .home => try std.fmt.format(writer, "home", .{}),
            .end => try std.fmt.format(writer, "end", .{}),

            else => try std.fmt.format(writer, "Not available yet", .{}),
        }
    }
};

/// Returns the next event received.
/// If raw term is `.blocking` or term is canonical it will block until read at least one event.
/// otherwise it will return `.none` if it didnt read any event
///
/// `in`: needs to be reader
pub fn next(in: anytype) !Event {
    // TODO: Check buffer size
    var buf: [20]u8 = undefined;
    const c = try in.read(&buf);
    if (c == 0) {
        return .none;
    }

    const view = try std.unicode.Utf8View.init(buf[0..c]);
    var iter = view.iterator();
    const event: Event = .none;

    // TODO: Find a better way to iterate buffer
    if (iter.nextCodepoint()) |c0| switch (c0) {
        '\x1b' => {
            if (iter.nextCodepoint()) |c1| switch (c1) {
                // fn (1 - 4)
                // O - 0x6f - 111
                '\x4f' => {
                    return Event{ .key = Key{ .fun = (1 + buf[2] - '\x50') } };
                },

                // csi
                '[' => {
                    return try parse_csi(buf[2..c]);
                },

                '\x01'...'\x0C', '\x0E'...'\x1A' => return Event{ .key = Key{ .ctrl_alt = c1 + '\x60' } },

                // alt key
                else => {
                    return Event{ .key = Key{ .alt = c1 } };
                },
            } else {
                return Event{ .key = .esc };
            }
        },

        // tab is equal to ctrl-i

        // ctrl keys (avoids ctrl-m)
        '\x01'...'\x0C', '\x0E'...'\x1A' => return Event{ .key = Key{ .ctrl = c0 + '\x60' } },

        // special chars
        '\x7f' => return Event{ .key = .backspace },
        '\x0D' => return Event{ .key = .enter },

        // chars and shift + chars
        else => return Event{ .key = Key{ .char = c0 } },
    };

    return event;
}

fn parse_csi(buf: []const u8) !Event {
    switch (buf[0]) {
        // keys
        'A' => return Event{ .key = .up },
        'B' => return Event{ .key = .down },
        'C' => return Event{ .key = .right },
        'D' => return Event{ .key = .left },

        '1' => {
            switch (buf[1]) {
                '5' => return Event{ .key = Key{ .fun = 5 } },
                '7' => return Event{ .key = Key{ .fun = 6 } },
                '8' => return Event{ .key = Key{ .fun = 7 } },
                '9' => return Event{ .key = Key{ .fun = 8 } },
                '~' => return Event{ .key = .home },
                // shift + arrow keys
                ';' => {
                    switch (buf[2]) {
                        '2' => {
                            switch (buf[3]) {
                                'A' => return Event{ .key = .shift_up },
                                'B' => return Event{ .key = .shift_down },
                                'C' => return Event{ .key = .shift_right },
                                'D' => return Event{ .key = .shift_left },
                                else => {},
                            }
                        },
                        '5' => {
                            switch (buf[3]) {
                                'A' => return Event{ .key = .ctrl_up },
                                'B' => return Event{ .key = .ctrl_down },
                                'C' => return Event{ .key = .ctrl_right },
                                'D' => return Event{ .key = .ctrl_left },
                                else => {},
                            }
                        },
                        '6' => {
                            switch (buf[3]) {
                                'A' => return Event{ .key = .ctrl_shift_up },
                                'B' => return Event{ .key = .ctrl_shift_down },
                                'C' => return Event{ .key = .ctrl_shift_right },
                                'D' => return Event{ .key = .ctrl_shift_left },
                                else => {},
                            }
                        },

                        '7' => {
                            switch (buf[3]) {
                                'A' => return Event{ .key = .ctrl_alt_up },
                                'B' => return Event{ .key = .ctrl_alt_down },
                                'C' => return Event{ .key = .ctrl_alt_right },
                                'D' => return Event{ .key = .ctrl_alt_left },
                                else => {},
                            }
                        },

                        else => {},
                    }
                },
                else => {},
            }
        },

        '2' => {
            switch (buf[1]) {
                '0' => return Event{ .key = Key{ .fun = 9 } },
                '1' => return Event{ .key = Key{ .fun = 10 } },
                '3' => return Event{ .key = Key{ .fun = 11 } },
                '4' => return Event{ .key = Key{ .fun = 12 } },
                '~' => return Event{ .key = .insert },
                else => {},
            }
        },

        '3' => return Event{ .key = .delete },
        '4' => return Event{ .key = .end },
        '5' => return Event{ .key = .page_up },
        '6' => return Event{ .key = .page_down },

        else => {},
    }

    return .not_supported;
}

pub const Event = union(enum) {
    key: Key,
    resize,
    not_supported,
    none,
};

test "next" {
    const term = @import("main.zig").term;

    const tty = (try std.fs.cwd().openFile("/dev/tty", .{})).reader();

    var raw = try term.enableRawMode(tty.context.handle, .blocking);
    defer raw.disableRawMode() catch {};

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const key = try next(tty);
        std.debug.print("\n\r{any}\n", .{key});
    }
}
