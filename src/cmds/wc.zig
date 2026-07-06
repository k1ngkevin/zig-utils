const std = @import("std");

const Counts = struct {
    lines: u64,
    words: u64,
    bytes: u64,

    pub fn addCounts(self: *Counts, other: Counts) void {
        self.lines += other.lines;
        self.words += other.words;
        self.bytes += other.bytes;
    }
};

pub fn run(io: std.Io, args: []const []const u8) !void {
    var count_bytes = false;
    var count_words = false;
    var count_lines = false;
    var any_count_flag = false;
    var positional_start: usize = 0;

    for (args, 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-c")) {
            count_bytes = true;
            any_count_flag = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-w")) {
            count_words = true;
            any_count_flag = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-l")) {
            count_lines = true;
            any_count_flag = true;
            continue;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("wc: invalid option: {s}\n", .{arg});
            return;
        } else {
            positional_start = i;
            break;
        }
    } else {
        positional_start = args.len;
    }

    if (!any_count_flag) {
        count_lines = true;
        count_words = true;
        count_bytes = true;
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    var total_counts = Counts{
        .lines = 0,
        .words = 0,
        .bytes = 0,
    };

    const positional_args = args[positional_start..];
    if (positional_args.len > 0) {
        try printHeader(
            stdout_writer,
            count_lines,
            count_words,
            count_bytes,
            true,
        );
    }

    for (positional_args) |arg| {
        var file = std.Io.Dir.cwd().openFile(io, arg, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("error: \"{s}\" : no such file or directory\n", .{args[0]});
                return;
            },
            else => return err,
        };
        defer file.close(io);

        var reader_buffer: [8 * 1024]u8 = undefined;
        var reader_state = file.reader(io, &reader_buffer);
        const reader = &reader_state.interface;

        var read_buffer: [8 * 1024]u8 = undefined;
        const counts = try countFile(reader, &read_buffer);
        total_counts.addCounts(counts);

        try printCounts(
            stdout_writer,
            counts,
            arg,
            count_lines,
            count_words,
            count_bytes,
        );
    }

    if (positional_args.len > 1) {
        try printCounts(
            stdout_writer,
            total_counts,
            "total",
            count_lines,
            count_words,
            count_bytes,
        );
    }

    try stdout_writer.flush();
}

pub fn countFile(reader: *std.Io.Reader, read_buffer: []u8) !Counts {
    var counts = Counts{
        .lines = 0,
        .words = 0,
        .bytes = 0,
    };

    var in_word = false;
    while (true) {
        const n = try reader.readSliceShort(read_buffer);
        if (n == 0) break;

        const bytes = read_buffer[0..n];

        counts.bytes += n;

        for (bytes) |byte| {
            if (std.ascii.isWhitespace(byte)) {
                in_word = false;
            } else if (!in_word) {
                counts.words += 1;
                in_word = true;
            }
            if (byte == '\n') {
                counts.lines += 1;
            }
        }
    }
    return counts;
}

fn printCounts(
    writer: *std.Io.Writer,
    counts: Counts,
    filename: ?[]const u8,
    count_lines: bool,
    count_words: bool,
    count_bytes: bool,
) !void {
    if (count_lines) {
        try writer.print("{d: >8} ", .{counts.lines});
    }
    if (count_words) {
        try writer.print("{d: >8} ", .{counts.words});
    }
    if (count_bytes) {
        try writer.print("{d: >8} ", .{counts.bytes});
    }
    if (filename) |name| {
        try writer.print("{s}", .{name});
    }
    try writer.writeByte('\n');
}

fn printHeader(
    writer: *std.Io.Writer,
    count_lines: bool,
    count_words: bool,
    count_bytes: bool,
    print_filename: bool,
) !void {
    if (count_lines) {
        try writer.print("{s: >8} ", .{"lines"});
    }
    if (count_words) {
        try writer.print("{s: >8} ", .{"words"});
    }
    if (count_bytes) {
        try writer.print("{s: >8} ", .{"bytes"});
    }
    if (print_filename) {
        try writer.print("{s}", .{"file"});
    }
    try writer.writeByte('\n');
}
