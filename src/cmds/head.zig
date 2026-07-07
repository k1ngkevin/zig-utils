const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var display_lines = true;
    var display_bytes = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-n")) {
            display_lines = true;
            display_bytes = false;
            continue;
        } else if (std.mem.eql(u8, arg, "-c")) {
            display_bytes = true;
            display_lines = false;
            continue;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("head: invalid option: {s}\n", .{arg});
            return;
        } else {
            positional_start = i;
            break;
        }
    } else {
        positional_start = args.len;
    }

    var stdout_buffer: [4 * 1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var head_count: u64 = 10;

    var n: ?u64 = null;

    if (positional_start < args.len) {
        n = std.fmt.parseInt(u64, args[positional_start], 10) catch null;
    }

    if (n != null) {
        head_count = n.?;
        positional_start += 1;
    }

    if (head_count == 0) {
        if (display_bytes) {
            std.debug.print("head: illegal byte count -- 0\n", .{});
            return;
        } else {
            std.debug.print("head: illegal line count -- 0\n", .{});
            return;
        }
    }

    const positional_args = args[positional_start..];

    if (positional_args.len == 0) {
        var stdin_buffer: [8 * 1024]u8 = undefined;
        var stdin_reader_state = std.Io.File.stdin().reader(io, &stdin_buffer);
        const stdin_reader = &stdin_reader_state.interface;

        var read_buffer: [8 * 1024]u8 = undefined;

        if (display_bytes) {
            try fileHeadByte(stdin_reader, &read_buffer, stdout, head_count);
        } else {
            try fileHeadLine(stdin_reader, &read_buffer, stdout, head_count);
        }

        try stdout.flush();
        return;
    }

    for (positional_args) |arg| {
        var file = std.Io.Dir.cwd().openFile(io, arg, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("error: \"{s}\" : no such file or directory\n", .{args[0]});
                return;
            },
            else => return err,
        };
        defer file.close(io);

        var read_buffer: [8 * 1024]u8 = undefined;
        var reader_state = file.reader(io, &read_buffer);
        const reader = &reader_state.interface;

        var output_buffer: [8 * 1024]u8 = undefined;

        try stdout.print("==> {s} <==\n", .{arg});

        if (display_bytes) {
            try fileHeadByte(reader, &output_buffer, stdout, head_count);
        } else {
            try fileHeadLine(reader, &output_buffer, stdout, head_count);
        }
    }

    try stdout.flush();
}

pub fn fileHeadLine(reader: *std.Io.Reader, read_buffer: []u8, writer: *std.Io.Writer, num_lines: u64) !void {
    var current_line: u64 = 0;
    outer: while (current_line < num_lines) {
        const n = try reader.readSliceShort(read_buffer);

        if (n == 0) break;

        const bytes = read_buffer[0..n];

        for (bytes) |byte| {
            try writer.writeByte(byte);
            if (byte == '\n') {
                current_line += 1;

                if (current_line >= num_lines) {
                    break :outer;
                }
            }
        }
    }
    try writer.flush();
}

pub fn fileHeadByte(reader: *std.Io.Reader, read_buffer: []u8, writer: *std.Io.Writer, num_bytes: u64) !void {
    var current_byte: u64 = 0;
    while (current_byte < num_bytes) {
        const n = try reader.readSliceShort(read_buffer);

        if (n == 0) break;

        const remaining = num_bytes - current_byte;
        const amount: usize = @intCast(@min(remaining, n));

        try writer.writeAll(read_buffer[0..amount]);

        current_byte += amount;
    }
    try writer.flush();
}
