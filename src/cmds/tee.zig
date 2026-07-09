const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var append_mode = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-a")) {
            append_mode = true;
            continue;
        } else {
            positional_start = i;
            break;
        }
    } else {
        positional_start = args.len;
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;
    var output_buffer: [4 * 1024]u8 = undefined;

    var stdin_buffer: [4 * 1024]u8 = undefined;
    var stdin_reader_state = std.Io.File.stdin().reader(io, &stdin_buffer);
    const stdin_reader = &stdin_reader_state.interface;

    const positional_args = args[positional_start..];

    if (positional_args.len == 0) {
        try tee(
            io,
            stdin_reader,
            &output_buffer,
            stdout,
            null,
            append_mode,
        );
        try stdout.flush();
        return;
    }

    for (positional_args) |arg| {
        const cwd = std.Io.Dir.cwd();
        var file = cwd.createFile(
            io,
            arg,
            .{ .truncate = !append_mode },
        ) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("tee: {s}: no such file or directory\n", .{arg});
                try tee(
                    io,
                    stdin_reader,
                    &output_buffer,
                    stdout,
                    null,
                    append_mode,
                );
                try stdout.flush();
                return;
            },
            else => return err,
        };
        defer file.close(io);

        try tee(
            io,
            stdin_reader,
            &output_buffer,
            stdout,
            file,
            append_mode,
        );
    }

    try stdout.flush();
}

pub fn tee(
    io: std.Io,
    reader: *std.Io.Reader,
    read_buffer: []u8,
    writer: *std.Io.Writer,
    file: ?std.Io.File,
    append_mode: bool,
) !void {
    var offset: u64 = if (file) |f|
        if (append_mode) try f.length(io) else 0
    else
        0;

    while (true) {
        const n = try reader.readSliceShort(read_buffer);
        if (n == 0) break;

        const bytes = read_buffer[0..n];
        try writer.writeAll(bytes);

        if (file) |f| {
            try f.writePositionalAll(io, bytes, offset);
            offset += n;
        }
    }
}
