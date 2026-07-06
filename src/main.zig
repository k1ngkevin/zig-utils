const std = @import("std");
const echo = @import("cmds/echo.zig");
const pwd = @import("cmds/pwd.zig");
const cat = @import("cmds/cat.zig");
const wc = @import("cmds/wc.zig");
const head = @import("cmds/head.zig");

const Utils = enum { echo, pwd, cat, wc, head };

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(arena);

    if (args.len < 2) {
        std.debug.print("usage: zigutils <util> [arguments...]\n", .{});
        return;
    }

    if (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-help")) {
        std.debug.print("usage: zigutils <util> [arguments...]\n\n", .{});
        std.debug.print("currently supported utils: \n", .{});
        inline for (std.meta.fields(Utils)) |util| {
            std.debug.print("- {s}\n", .{util.name});
        }
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
        .pwd => try pwd.run(io, command_args),
        .cat => try cat.run(io, command_args),
        .wc => try wc.run(io, command_args),
        .head => try head.run(io, command_args),
    }
}
