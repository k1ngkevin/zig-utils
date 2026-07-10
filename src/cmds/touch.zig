const std = @import("std");

pub fn run(io: std.Io, args: []const []const u8) !void {
    if (args.len == 0) {
        printHelp();
        return;
    }

    var no_create = false;
    var change_modification_time = false;
    var change_access_time = false;

    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (arg.len > 1 and arg[0] == '-') {
            for (arg[1..]) |ch| {
                switch (ch) {
                    'c' => no_create = true,
                    'm' => change_modification_time = true,
                    'a' => change_access_time = true,
                    else => {
                        std.debug.print("touch: unknown flag -{c}", .{ch});
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

    const update_access_time = change_access_time or
        (!change_access_time and !change_modification_time);

    const update_modification_time = change_modification_time or
        (!change_access_time and !change_modification_time);

    for (positional_args) |arg| {
        var file = if (no_create) std.Io.Dir.cwd().openFile(io, arg, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                return;
            },
            else => return err,
        } else std.Io.Dir.cwd().createFile(io, arg, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("touch: \"{s}\" : no such file or directory\n", .{args[0]});
                return;
            },
            else => return err,
        };
        defer file.close(io);

        try file.setTimestamps(io, .{
            .access_timestamp = if (update_access_time) .now else .unchanged,
            .modify_timestamp = if (update_modification_time) .now else .unchanged,
        });
    }
}

fn printHelp() void {
    std.debug.print("usage: touch file ...\n", .{});
    std.debug.print("flags:\n", .{});
    std.debug.print("-c : do not create any files\n", .{});
    std.debug.print("-m : Change modification time of file\n", .{});
    std.debug.print("-a : Change access time of file\n", .{});
}
