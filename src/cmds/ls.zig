const std = @import("std");

const HiddenMode = enum {
    none,
    almost_all, // -A
    all, // -a
};

const lsFlags = struct {
    hidden_mode: HiddenMode = .none,
    one_per_line: bool = false,
};

pub fn run(io: std.Io, args: []const []const u8) !void {
    var flags = lsFlags{};
    var positional_start: usize = 0;

    var stdout_buffer: [4 * 1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    for (args, 0..) |arg, i| {
        if (arg.len > 1 and arg[0] == '-') {
            for (arg[1..]) |ch| {
                switch (ch) {
                    'A' => flags.hidden_mode = .almost_all,
                    'a' => flags.hidden_mode = .all,
                    '1' => flags.one_per_line = true,
                    else => {
                        std.debug.print("ls: unknown flag -{c}\n", .{ch});
                        return;
                    },
                }
            }
            continue;
        } else {
            positional_start = i;
            break;
        }
    } else {
        positional_start = args.len;
    }

    const postional_args = args[positional_start..];

    if (postional_args.len == 0) {
        var dir: std.Io.Dir = try std.Io.Dir.cwd().openDir(
            io,
            ".",
            .{ .iterate = true },
        );
        defer dir.close(io);

        try ls(io, dir, stdout, flags);
        return;
    }

    for (postional_args) |arg| {
        var dir: std.Io.Dir = try std.Io.Dir.cwd().openDir(
            io,
            arg,
            .{ .iterate = true },
        );
        defer dir.close(io);

        try ls(io, dir, stdout, flags);
    }
}

pub fn shouldInclude(name: []const u8, hidden_mode: HiddenMode) bool {
    const hidden = name.len > 0 and name[0] == '.';
    return switch (hidden_mode) {
        .none => !hidden,
        .all, .almost_all => true,
    };
}

pub fn printEntry(name: []const u8, writer: *std.Io.Writer, one_per_line: bool) !void {
    if (one_per_line) {
        try writer.print("{s}\n", .{name});
    } else {
        try writer.print("{s}  ", .{name});
    }
}

pub fn ls(io: std.Io, dir: std.Io.Dir, writer: *std.Io.Writer, flags: lsFlags) !void {
    var dirIterator = dir.iterate();
    while (try dirIterator.next(io)) |dirContent| {
        if (!shouldInclude(dirContent.name, flags.hidden_mode)) {
            continue;
        }

        try printEntry(dirContent.name, writer, flags.one_per_line);
    }
    if (!flags.one_per_line) {
        try writer.writeByte('\n');
    }

    try writer.flush();
}
