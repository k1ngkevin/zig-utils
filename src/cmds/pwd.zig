const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;
    if (args.len > 0) {
        try stdout.writeAll("pwd: too many arguments\n");
        return;
    }

    const cwd = std.Io.Dir.cwd();
    var cwd_buffer: [std.fs.max_path_bytes]u8 = undefined;

    if (cwd.realPathFile(io, ".", &cwd_buffer)) |n_len| {
        try stdout.print("{s}\n", .{cwd_buffer[0..n_len]});
    } else |err_x| {
        try stdout.print("Error {any}\n", .{err_x});
    }
}
