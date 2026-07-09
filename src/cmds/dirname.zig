const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    if (args.len == 0) {
        std.debug.print("usage: dirname string [...]\n", .{});
        return;
    }

    for (args) |arg| {
        const dirname = std.fs.path.dirname(arg) orelse
            if (std.fs.path.isAbsolute(arg)) std.fs.path.sep_str else ".";
        try stdout.writeAll(dirname);
        try stdout.writeByte('\n');
    }

    try stdout.flush();
}
