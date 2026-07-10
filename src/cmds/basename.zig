const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    if (args.len == 0) {
        std.debug.print("usage: basename string [suffix]\n", .{});
        std.debug.print("       basename [-a] [-s suffix] string [...]\n", .{});
        return;
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    var all_mode = false;
    var suffix_mode = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-a")) {
            all_mode = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-s")) {
            suffix_mode = true;
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
        std.debug.print("usage: basename string [suffix]\n", .{});
        std.debug.print("       basename [-a] [-s suffix] string [...]\n", .{});
        return;
    }

    const suffix = if (suffix_mode) positional_args[0] else null;
    const file_args = if (suffix_mode) positional_args[1..] else positional_args;

    if (file_args.len == 0) {
        std.debug.print("usage: basename string [suffix]\n", .{});
        std.debug.print("       basename [-a] [-s suffix] string [...]\n", .{});
        return;
    }

    if (!all_mode and !suffix_mode and file_args.len == 2) {
        const basename = std.fs.path.basename(file_args[0]);
        const suffix_arg = file_args[1];
        const new_basename = std.mem.cutSuffix(u8, basename, suffix_arg) orelse basename;

        try stdout.writeAll(new_basename);
        try stdout.writeByte('\n');
    } else {
        for (file_args) |arg| {
            const basename = std.fs.path.basename(arg);

            const new_basename = if (suffix) |s|
                std.mem.cutSuffix(u8, basename, s) orelse basename
            else
                basename;

            try stdout.writeAll(new_basename);
            try stdout.writeByte('\n');
        }
    }

    try stdout.flush();
}
