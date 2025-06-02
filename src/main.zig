const std = @import("std");
const clap = @import("clap.zig");
const cfg = @import("config.zig");

const major: u32 = 0;
const minor: u32 = 0;
const patch: u32 = 0;

const hex_lowercase = "0123456789abcdef";
const usage_str = "Usage: xxz [options] [infile [outfile]]\n";
const help_str = "\n";
const version_str = "version {}.{}.{}\n";

pub fn print_usage(writer: anytype) !void {
    try writer.print(usage_str, .{});
}

pub fn print_help(writer: anytype) !void {
    try writer.print(help_str, .{});
}

pub fn print_version(writer: anytype) !void {
    try writer.print(version_str, .{ major, minor, patch });
}

pub fn print_usage_error(writer: anytype, err: []const u8) !void {
    try writer.print("Error: {s}.\n", .{err});
    try print_usage(writer);
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
        switch (err) {
            clap.ParseError.InvalidOption => {
                try print_usage_error(stderr, "invalid option");
            },
            clap.ParseError.MissingOptionArgument => {
                try print_usage_error(stderr, "option is missing its argument");
            },
            clap.ParseError.ExpectedUnsignedArgument => {
                try print_usage_error(stderr, "expected unsigned integer argument");
            },
            clap.ParseError.ExpectedSignedArgument => {
                try print_usage_error(stderr, "expected signed integer argument");
            },
            clap.ParseError.InvalidColorizeMode => {
                try print_usage_error(stderr, "invalid colorize mode");
            },
            clap.ParseError.InvalidFileArguments => {
                try print_usage_error(stderr, "invalid in/out file arguments");
            },
        }
        try stderr_bw.flush();
        return;
    };

    const stdout_file = std.io.getStdOut();
    var stdout_bw = std.io.bufferedWriter(stdout_file.writer());
    const stdout = stdout_bw.writer();

    if (options.help) {
        try print_help(stdout);
        try stdout_bw.flush();
        return;
    }

    if (options.version) {
        try print_version(stdout);
        try stdout_bw.flush();
        return;
    }

    const config = cfg.Config.init(allocator, options) catch |err| {
        switch (err) {
            error.IncompatableOptions => {
                try print_usage_error(stderr, "only one of -b, -e, -u, -p, -i can be used\n");
            },
            else => {
                try print_usage_error(stderr, "unexpected error\n");
            },
        }
        try stderr_bw.flush();
        return;
    };
    defer config.deinit(allocator);

    const in_file = if (options.in_file) |path|
        std.fs.cwd().openFile(path, .{}) catch |err| {
            switch (err) {
                std.fs.File.OpenError.FileNotFound => {
                    try stderr.print("Error: input file not found: {s}\n", .{path});
                },
                std.fs.File.OpenError.AccessDenied => {
                    try stderr.print("Error: invalid input file permissions: {s}\n", .{path});
                },
                else => try stderr.print("Error: could not open input file: {s}\n", .{path}),
            }
            try stderr_bw.flush();
            return;
        }
    else
        std.io.getStdIn();
    const should_close_in_file = options.in_file != null;

    var in_br = std.io.bufferedReader(in_file.reader());
    const in_stream = in_br.reader();

    const out_file = if (options.out_file) |path|
        std.fs.cwd().openFile(path, std.fs.File.OpenFlags{
            .mode = std.fs.File.OpenMode.write_only,
        }) catch |err| {
            switch (err) {
                std.fs.File.OpenError.FileNotFound => {
                    try stderr.print("Error: output file not found: {s}\n", .{path});
                },
                std.fs.File.OpenError.AccessDenied => {
                    try stderr.print("Error: invalid output file permissions: {s}\n", .{path});
                },
                else => try stderr.print("Error: could not open output file: {s}\n", .{path}),
            }
            try stderr_bw.flush();
            return;
        }
    else
        std.io.getStdOut();
    const should_close_out_file = options.out_file != null;

    var out_br = std.io.bufferedWriter(out_file.writer());
    const out_stream = out_br.writer();

    var buf: [1024]u8 = undefined;

    const bytes_read = in_stream.readAll(&buf) catch |err| return err;

    for (0..bytes_read) |i| {
        const byte = buf[i];

        const high: u8 = (byte & 0xF0) >> 4;
        const low: u8 = byte & 0x0F;

        try out_stream.print("0x{c}{c},", .{ hex_lowercase[high], hex_lowercase[low] });
    }
    try out_stream.print("\n", .{});

    try out_br.flush();

    if (should_close_in_file)
        in_file.close();

    if (should_close_out_file)
        out_file.close();
}
