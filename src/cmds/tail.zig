const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8, allocator: std.mem.Allocator) !void {
    var display_lines = true;
    var display_bytes = false;
    var flag_passed = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-n")) {
            display_lines = true;
            display_bytes = false;
            flag_passed = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-c")) {
            display_bytes = true;
            display_lines = false;
            flag_passed = true;
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
    } else if (args.len == 1 and flag_passed) {
        std.debug.print("tail: option requires and argument: {s}\n", .{args[0]});
        return;
    } else if (n == null and flag_passed) {
        std.debug.print("tail: illegal offset -- {s}\n", .{args[positional_start]});
        return;
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

    for (positional_args) |arg| {
        var file = std.Io.Dir.cwd().openFile(io, arg, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("error: \"{s}\" : no such file or directory\n", .{args[0]});
                return;
            },
            else => return err,
        };
        defer file.close(io);

        if (display_lines) {
            try tailLineSeekable(io, file, stdout, tail_count);
        } else {
            try tailByteSeekable(io, file, stdout, tail_count);
        }

        try stdout.print("==> {s} <==\n", .{arg});
    }
}

pub fn tailLineStream(
    reader: *std.Io.Reader,
    read_buffer: []u8,
    writer: *std.Io.Writer,
    num_lines: u64,
    allocator: std.mem.Allocator,
) !void {
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

pub fn tailByteStream(
    reader: *std.Io.Reader,
    read_buffer: []u8,
    writer: *std.Io.Writer,
    num_bytes: u64,
    allocator: std.mem.Allocator,
) !void {
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

pub fn tailLineSeekable(
    io: std.Io,
    file: std.Io.File,
    writer: *std.Io.Writer,
    num_lines: u64,
) !void {
    const end: u64 = try file.length(io);

    var lines_read: u64 = 0;
    var pos = end;
    var read_buffer: [4 * 1024]u8 = undefined;

    while (pos > 0) {
        const chunk_start: u64 = if (pos > read_buffer.len) pos - read_buffer.len else 0;
        const read_amount: usize = @intCast(pos - chunk_start);

        const n = try file.readPositionalAll(io, read_buffer[0..read_amount], chunk_start);

        var i: usize = n;
        while (i > 0) {
            i -= 1;

            if (read_buffer[i] == '\n') {
                lines_read += 1;
            }

            if (lines_read > num_lines) {
                var offset = chunk_start + i + 1;
                while (offset < end) {
                    const remaining = end - offset;
                    const amount: usize = @intCast(@min(remaining, read_buffer.len));

                    const read_pos = try file.readPositionalAll(io, read_buffer[0..amount], offset);
                    if (read_pos == 0) break;

                    try writer.writeAll(read_buffer[0..read_pos]);
                    offset += read_pos;
                }
                try writer.flush();
                return;
            }
        }
        if (chunk_start == 0) break;
        pos = chunk_start;
    }

    var offset: usize = 0;

    while (true) {
        const read_pos = try file.readPositionalAll(io, &read_buffer, offset);
        if (read_pos == 0) break;

        try writer.writeAll(read_buffer[0..read_pos]);
        offset += read_pos;
    }

    try writer.flush();
}

pub fn tailByteSeekable(
    io: std.Io,
    file: std.Io.File,
    writer: *std.Io.Writer,
    num_bytes: u64,
) !void {
    const end: u64 = try file.length(io);
    var offset: u64 = if (end > num_bytes) end - num_bytes else 0;

    var read_buffer: [4 * 1024]u8 = undefined;

    while (offset < end) {
        const remaining = end - offset;
        const read_amount: usize = @intCast(@min(remaining, read_buffer.len));

        const n = try file.readPositionalAll(io, read_buffer[0..read_amount], offset);
        if (n == 0) break;

        try writer.writeAll(read_buffer[0..n]);
        offset += n;
    }

    try writer.flush();
}
