const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var newline: bool = true;
    var interpret_esc: bool = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-n")) {
            newline = false;
            continue;
        } else if (std.mem.eql(u8, arg, "-e")) {
            interpret_esc = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-E")) {
            interpret_esc = false;
            continue;
        } else {
            positional_start = i;
            break;
        }
    } else {
        positional_start = args.len;
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    const print_args = args[positional_start..];

    for (print_args, 0..) |arg, i| {
        if (interpret_esc) {
            try interpretEscCharacter(stdout_writer, arg);
        } else {
            try stdout_writer.print("{s}", .{arg});
        }

        if (i < print_args.len - 1) {
            try stdout_writer.writeByte(' ');
        }
    }

    if (newline) {
        try stdout_writer.writeByte('\n');
    }

    try stdout_writer.flush();
}

pub fn interpretEscCharacter(writer: anytype, str: []const u8) !void {
    var i: usize = 0;

    while (i < str.len) {
        if (str[i] == '\\' and i + 1 < str.len) {
            switch (str[i + 1]) {
                'n' => try writer.writeByte('\n'),
                't' => try writer.writeByte('\t'),
                'r' => try writer.writeByte('\r'),
                '\\' => try writer.writeByte('\\'),
                'b' => try writer.writeByte(8),
                'v' => try writer.writeByte(11),
                'e' => try writer.writeByte(27),
                else => try writer.writeByte(str[i + 1]),
            }
            i += 2;
        } else {
            try writer.writeByte(str[i]);
            i += 1;
        }
    }
}
