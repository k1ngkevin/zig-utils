const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var line_numbers = false;
    var unbuffered = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-n")) {
            line_numbers = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-u")) {
            unbuffered = true;
            continue;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("cat: invalid option: {s}\n", .{arg});
            return;
        } else {
            positional_start = i;
            break;
        }
    } else {
        positional_start = args.len;
    }

    var stdout_buffer: [8 * 1024]u8 = undefined;
    var stdout_writer: std.Io.File.Writer = if (unbuffered)
        std.Io.File.stdout().writer(io, &.{})
    else
        std.Io.File.stdout().writer(io, &stdout_buffer);

    const stdout = &stdout_writer.interface;

    const positional_args = args[positional_start..];

    for (positional_args) |arg| {
        var file = std.Io.Dir.cwd().openFile(io, arg, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("error: \"{s}\" : no such file or directory\n", .{args[0]});
                return;
            },
            else => return err,
        };
        defer file.close(io);

        var reader_buffer: [8 * 1024]u8 = undefined;
        var reader_state = file.reader(io, &reader_buffer);
        const reader = &reader_state.interface;

        var read_buffer: [8 * 1024]u8 = undefined;

        if (line_numbers) {
            try catNewline(reader, &read_buffer, stdout);
        } else {
            try cat(reader, &read_buffer, stdout);
        }
    }
}

pub fn cat(reader: *std.Io.Reader, read_buffer: []u8, writer: *std.Io.Writer) !void {
    while (true) {
        const n = try reader.readSliceShort(read_buffer);
        if (n == 0) break;
        const bytes = read_buffer[0..n];

        try writer.writeAll(bytes);
    }
    try writer.flush();
}

pub fn catNewline(reader: *std.Io.Reader, read_buffer: []u8, writer: *std.Io.Writer) !void {
    var current_line: u32 = 1;
    var at_start = true;

    while (true) {
        const n = try reader.readSliceShort(read_buffer);
        if (n == 0) break;

        const bytes = read_buffer[0..n];

        for (bytes) |byte| {
            if (at_start) {
                try writer.print("{d}.\t", .{current_line});
                current_line += 1;
                at_start = false;
            }

            try writer.writeByte(byte);

            if (byte == '\n') {
                at_start = true;
            }
        }
    }
    try writer.flush();
}
