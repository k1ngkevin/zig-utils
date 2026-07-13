const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    var create_parents = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-p")) {
            create_parents = true;
            continue;
        } else {
            positional_start = i;
            break;
        }
    } else {
        positional_start = args.len;
    }

    const positional_args = args[positional_start..];

    if (positional_args.len == 0) {
        std.debug.print("usage: mkdir directory_name ...\n", .{});
        std.debug.print("flags\n", .{});
        std.debug.print("-p: create intermediate directories\n", .{});
    }

    for (positional_args) |arg| {
        if (create_parents) {
            try std.Io.Dir.cwd().createDirPath(io, arg);
        } else {
            std.Io.Dir.cwd().createDir(io, arg, .default_dir) catch |err| switch (err) {
                error.FileNotFound => std.debug.print("mkdir: {s}: no such file or directory\n", .{arg}),
                else => return err,
            };
        }
    }
}
