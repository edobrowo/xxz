const std = @import("std");
const clap = @import("clap.zig");

const hex_lowercase = "0123456789abcdef";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const file = std.io.getStdIn();
    var br = std.io.bufferedReader(file.reader());
    const in_stream = br.reader();

    var buf: [1024]u8 = undefined;

    const stdout_file = std.io.getStdOut();
    var stdout_bw = std.io.bufferedWriter(stdout_file.writer());
    const stdout = stdout_bw.writer();

    const stderr_file = std.io.getStdOut();
    var stderr_bw = std.io.bufferedWriter(stderr_file.writer());
    const stderr = stderr_bw.writer();

    const options = clap.parse(args[1..]) catch |err| {
        switch (err) {
            error.InvalidOption => try stderr.print("invalid option\n", .{}),
            error.MissingOptionArgument => try stderr.print("option is missing its argument\n", .{}),
            error.ExpectedUnsigned => try stderr.print("expected unsigned integer argument\n", .{}),
            error.ExpectedSigned => try stderr.print("expected signed integer argument\n", .{}),
            error.InvalidColorizeMode => try stderr.print("invalid colorize mode\n", .{}),
            else => try stderr.print("unexpected error\n", .{}),
        }
        try stderr_bw.flush();
        return;
    };

    try stdout.print("{}\n", .{options});
    try stdout_bw.flush();

    const bytes_read = in_stream.readAll(&buf) catch |err| return err;

    for (0..bytes_read) |i| {
        const byte = buf[i];

        const high: u8 = (byte & 0xF0) >> 4;
        const low: u8 = byte & 0x0F;

        try stdout.print("0x{c}{c},", .{ hex_lowercase[high], hex_lowercase[low] });
    }
    try stdout.print("\n", .{});

    try stdout_bw.flush();
}
