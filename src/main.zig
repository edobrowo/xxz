const std = @import("std");
const clap = @import("clap.zig");
const cfg = @import("config.zig");
const xxzfmt = @import("fmt.zig");

const major: u32 = 0;
const minor: u32 = 0;
const patch: u32 = 0;

const usage_str = "Usage: xxz [options] [infile [outfile]]\n";
const help_str = "\n";
const version_str = "version {}.{}.{}\n";

pub fn printUsage(writer: anytype) !void {
    try writer.print(usage_str, .{});
}

pub fn printHelp(writer: anytype) !void {
    try writer.print(help_str, .{});
}

pub fn printVersion(writer: anytype) !void {
    try writer.print(version_str, .{ major, minor, patch });
}

pub fn printUsageError(writer: anytype, err: []const u8) !void {
    try writer.print("Error: {s}.\n", .{err});
    try printUsage(writer);
}

pub fn printOptionsError(writer: anytype, err: clap.ParseError) !void {
    const msg = switch (err) {
        clap.ParseError.InvalidOption => "invalid option",
        clap.ParseError.MissingOptionArgument => "option is missing its argument",
        clap.ParseError.ExpectedUnsignedArgument => "expected unsigned integer argument",
        clap.ParseError.ExpectedSignedArgument => "expected signed integer argument",
        clap.ParseError.InvalidColorizeMode => "invalid colorize mode",
        clap.ParseError.InvalidFileArguments => "invalid in/out file arguments",
    };

    try printUsageError(writer, msg);
}

pub fn printConfigError(writer: anytype, err: anytype) !void {
    if (err == error.IncompatableOptions)
        try printUsageError(writer, "only one of -b, -e, -u, -p, -i can be used\n")
    else
        try printUsageError(writer, "unexpected error\n");
}

pub fn printFileOpenError(writer: anytype, path: []u8, err: std.fs.File.OpenError) !void {
    switch (err) {
        std.fs.File.OpenError.FileNotFound => {
            try writer.print("Error: file not found: {s}\n", .{path});
        },
        std.fs.File.OpenError.AccessDenied => {
            try writer.print("Error: invalid file permissions: {s}\n", .{path});
        },
        else => try writer.print("Error: could not open file: {s}\n", .{path}),
    }
}

fn dumpNormal(
    in_stream: anytype,
    out_stream: anytype,
    config: cfg.Config,
) !void {
    var buf: [1024]u8 = undefined;

    const partial_group_len = config.octets_per_line % config.octets_per_group;
    const has_partial_group = partial_group_len != 0;
    const partial_group_start = config.octets_per_line - partial_group_len;

    var line_idx: usize = 0;
    var line: usize = 0;
    while (true) {
        const bytes_read = in_stream.read(&buf) catch |err| return err;
        if (bytes_read == 0)
            break;

        var idx: usize = 0;
        while (idx < bytes_read) {
            if (line_idx == 0)
                try out_stream.print("{x:0>8}: ", .{line * config.octets_per_line});

            const group_end = @min(
                bytes_read,
                idx + config.octets_per_group,
                idx + config.octets_per_line - line_idx,
            );

            const bytes = buf[idx..group_end];
            try out_stream.print("{}", .{xxzfmt.fmtSliceHexLower(bytes)});

            line_idx += group_end - idx;
            idx = group_end;

            if (line_idx == config.octets_per_line or idx == bytes_read) {
                const text_start = idx - line_idx;
                const text_end = @min(bytes_read, idx);
                const text = buf[text_start..text_end];

                const remaining = config.octets_per_line - line_idx;
                const padding = 2 * (remaining + 1) + remaining / config.octets_per_group;
                const has_unfinished_group = remaining % config.octets_per_group != 0;
                try out_stream.writeByteNTimes(' ', padding);

                const is_last_group = line_idx > partial_group_start;
                if (has_partial_group and has_unfinished_group and !is_last_group)
                    try out_stream.writeByte(' ');

                for (text) |c|
                    try out_stream.writeByte(if (c == '\n') '.' else c);

                try out_stream.writeByte('\n');

                line_idx = 0;
                line += 1;
            } else if (line_idx > 0) try out_stream.writeByte(' ');
        }
    }
}

fn openInFileOrStdin(path_opt: ?[]const u8) !std.fs.File {
    return if (path_opt) |path|
        try std.fs.cwd().openFile(path, .{})
    else
        std.io.getStdIn();
}

fn openOutFileOrStdout(path_opt: ?[]const u8) !std.fs.File {
    return if (path_opt) |path|
        try std.fs.cwd().createFile(path, .{})
    else
        std.io.getStdOut();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const stderr_file = std.io.getStdErr();
    var stderr_bw = std.io.bufferedWriter(stderr_file.writer());
    const stderr = stderr_bw.writer();

    const options = clap.parse(args[1..]) catch |err| {
        try printOptionsError(stderr, err);
        try stderr_bw.flush();
        return;
    };

    const stdout_file = std.io.getStdOut();
    var stdout_bw = std.io.bufferedWriter(stdout_file.writer());
    const stdout = stdout_bw.writer();

    if (options.help) {
        try printHelp(stdout);
        try stdout_bw.flush();
        return;
    }

    if (options.version) {
        try printVersion(stdout);
        try stdout_bw.flush();
        return;
    }

    const config = cfg.Config.init(allocator, options) catch |err| {
        try printConfigError(stderr, err);
        try stderr_bw.flush();
        return;
    };
    defer config.deinit(allocator);

    const in_file = openInFileOrStdin(options.in_file) catch |err| {
        try printFileOpenError(stderr, options.in_file.?, err);
        try stderr_bw.flush();
        return;
    };
    const should_close_in_file = options.in_file != null;

    var in_br = std.io.bufferedReader(in_file.reader());
    const in_stream = in_br.reader();

    const out_file = openOutFileOrStdout(options.out_file) catch |err| {
        try printFileOpenError(stderr, options.out_file.?, err);
        try stderr_bw.flush();
        return;
    };
    const should_close_out_file = options.out_file != null;

    var out_br = std.io.bufferedWriter(out_file.writer());
    const out_stream = out_br.writer();

    try dumpNormal(in_stream, out_stream, config);

    try out_br.flush();

    if (should_close_in_file)
        in_file.close();

    if (should_close_out_file)
        out_file.close();
}
