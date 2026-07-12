const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    if (args.len == 0) {
        printHelp();
        return;
    }

    var no_create = false;
    var change_modification_time = false;
    var change_access_time = false;
    var use_reference_file = false;

    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (arg.len > 1 and arg[0] == '-') {
            for (arg[1..]) |ch| {
                switch (ch) {
                    'c' => no_create = true,
                    'm' => change_modification_time = true,
                    'a' => change_access_time = true,
                    'r' => use_reference_file = true,
                    else => {
                        std.debug.print("touch: unknown flag -{c}\n", .{ch});
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

    const positional_args = args[positional_start..];
    if (positional_args.len == 0) {
        printHelp();
        return;
    }

    if (use_reference_file and positional_args.len < 2) {
        std.debug.print("touch: missing file operand\n", .{});
        return;
    }

    const update_access_time = change_access_time or
        (!change_access_time and !change_modification_time);

    const update_modification_time = change_modification_time or
        (!change_access_time and !change_modification_time);

    const reference_file_path: []const u8 = if (use_reference_file) positional_args[0] else "";

    const reference_file_stats = if (use_reference_file) std.Io.Dir.cwd().statFile(
        io,
        reference_file_path,
        .{},
    ) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("touch: \"{s}\" : no such file or directory\n", .{reference_file_path});
            return;
        },
        else => return err,
    } else null;

    const target_args = if (use_reference_file)
        positional_args[1..]
    else
        positional_args;

    for (target_args) |arg| {
        var file = if (no_create) std.Io.Dir.cwd().openFile(io, arg, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        } else std.Io.Dir.cwd().createFile(io, arg, .{ .truncate = false }) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("touch: \"{s}\" : no such file or directory\n", .{arg});
                return;
            },
            else => return err,
        };
        defer file.close(io);

        try file.setTimestamps(io, .{
            .access_timestamp = if (update_access_time and use_reference_file)
                std.Io.File.SetTimestamp.init(reference_file_stats.?.atime)
            else if (update_access_time)
                .now
            else
                .unchanged,

            .modify_timestamp = if (update_modification_time and use_reference_file)
                .{ .new = reference_file_stats.?.mtime }
            else if (update_modification_time)
                .now
            else
                .unchanged,
        });
    }
}

fn printHelp() void {
    std.debug.print("usage: touch file ...\n", .{});
    std.debug.print("flags:\n", .{});
    std.debug.print("-c : do not create any files\n", .{});
    std.debug.print("-m : Change modification time of file\n", .{});
    std.debug.print("-a : Change access time of file\n", .{});
    std.debug.print("-r : Use times of reference file\n", .{});
}
