const std = @import("std");
const echo = @import("cmds/echo.zig");
const Io = std.Io;

const Utils = enum { echo };

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);

    if (args.len < 2) {
        std.debug.print("usage: zigutils <util> [arguments...]\n", .{});
        return;
    }

    if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-help")) {
        std.debug.print("usage: zigutils <util> [arguments...]\n", .{});
        std.debug.print("currently supported utils: \n - echo\n", .{});
        return;
    }

    const command = std.meta.stringToEnum(Utils, args[1]) orelse {
        std.log.err("Error: unknown util {s}\n\n" ++
            "run zigutils --help to see the list of currently supported utils\n", .{args[1]});
        return;
    };

    const command_args = args[2..];

    switch (command) {
        .echo => try echo.run(io, command_args),
    }
}
