const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8, allocator: std.mem.Allocator) !void {
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

    var tail_count: u64 = 10;

    var n: ?u64 = null;

    if (positional_start < args.len) {
        n = std.fmt.parseInt(u64, args[positional_start], 10) catch null;
    }

    if (n != null) {
        tail_count = n.?;
        positional_start += 1;
    }

    if (tail_count == 0) {
        if (display_bytes) {
            std.debug.print("tail: illegal byte count -- 0\n", .{});
            return;
        } else {
            std.debug.print("tail: illegal line count -- 0\n", .{});
            return;
        }
    }

    const positional_args = args[positional_start..];

    if (positional_args.len == 0) {
        var stdin_buffer: [8 * 1024]u8 = undefined;
        var stdin_reader_state = std.Io.File.stdin().reader(io, &stdin_buffer);
        const stdin_reader = &stdin_reader_state.interface;

        var read_buffer: [8 * 1024]u8 = undefined;

        if (display_lines) {
            try tailLineStream(
                stdin_reader,
                &read_buffer,
                stdout,
                tail_count,
                allocator,
            );
        } else {
            try tailByteStream(
                stdin_reader,
                &read_buffer,
                stdout,
                tail_count,
                allocator,
            );
        }

        try stdout.flush();
        return;
    }
}

pub fn tailLineStream(reader: *std.Io.Reader, read_buffer: []u8, writer: *std.Io.Writer, num_lines: u64, allocator: std.mem.Allocator) !void {
    var last_lines = try allocator.alloc([]u8, num_lines);
    defer allocator.free(last_lines);

    var count: usize = 0;
    var start: usize = 0;

    var current_line: std.ArrayList(u8) = .empty;

    while (true) {
        const n = try reader.readSliceShort(read_buffer);
        if (n == 0) break;

        const bytes = read_buffer[0..n];

        for (bytes) |byte| {
            try current_line.append(allocator, byte);

            if (byte == '\n') {
                const line_copy = try allocator.dupe(u8, current_line.items);

                if (count < last_lines.len) {
                    last_lines[(start + count) % last_lines.len] = line_copy;
                    count += 1;
                } else {
                    allocator.free(last_lines[start]);
                    last_lines[start] = line_copy;
                    start = (start + 1) % last_lines.len;
                }

                current_line.clearRetainingCapacity();
            }
        }
    }

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const arr_index = (start + i) % last_lines.len;
        try writer.writeAll(last_lines[arr_index]);
    }

    try writer.flush();
}

pub fn tailByteStream(reader: *std.Io.Reader, read_buffer: []u8, writer: *std.Io.Writer, num_bytes: u64, allocator: std.mem.Allocator) !void {
    var last_bytes = try allocator.alloc(u8, num_bytes);
    defer allocator.free(last_bytes);

    var count: usize = 0;
    var start: usize = 0;

    while (true) {
        const n = try reader.readSliceShort(read_buffer);
        if (n == 0) break;

        const bytes = read_buffer[0..n];

        for (bytes) |byte| {
            if (count < last_bytes.len) {
                last_bytes[(start + count) % last_bytes.len] = byte;
                count += 1;
            } else {
                last_bytes[start] = byte;
                start = (start + 1) % last_bytes.len;
            }
        }
    }

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const arr_index = (start + i) % last_bytes.len;
        try writer.writeByte(last_bytes[arr_index]);
    }

    try writer.flush();
}
