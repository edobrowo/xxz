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

    const stdin_file = std.io.getStdIn();
    var stdin_br = std.io.bufferedReader(stdin_file.reader());
    const stdin = stdin_br.reader();

    var buf: [1024]u8 = undefined;

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

    const config = try cfg.Config.init(allocator, options);
    try stdout.print("{}\n", .{config});
    try stdout_bw.flush();

    const bytes_read = stdin.readAll(&buf) catch |err| return err;

    for (0..bytes_read) |i| {
        const byte = buf[i];

        const high: u8 = (byte & 0xF0) >> 4;
        const low: u8 = byte & 0x0F;

        try stdout.print("0x{c}{c},", .{ hex_lowercase[high], hex_lowercase[low] });
    }
    try stdout.print("\n", .{});

    try stdout_bw.flush();
}
