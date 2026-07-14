const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var stdout_buffer: [4 * 1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (args.len == 0) {
        var dir: std.Io.Dir = try std.Io.Dir.cwd().openDir(
            io,
            ".",
            .{ .iterate = true },
        );
        defer dir.close(io);

        try ls(io, dir, stdout);
        return;
    }

    for (args) |arg| {
        var dir: std.Io.Dir = try std.Io.Dir.cwd().openDir(
            io,
            arg,
            .{ .iterate = true },
        );
        defer dir.close(io);

        try ls(io, dir, stdout);
    }
}

pub fn ls(io: std.Io, dir: std.Io.Dir, writer: *std.Io.Writer) !void {
    var dirIterator = dir.iterate();
    while (try dirIterator.next(io)) |dirContent| {
        if (dirContent.name[0] != '.') {
            try writer.print("{s}  ", .{dirContent.name});
        }
    }

    try writer.writeByte('\n');
    try writer.flush();
}
