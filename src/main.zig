const std = @import("std");

pub fn main() !void {
    const stdout_file = std.io.getStdOut();
    var stdout_bw = std.io.bufferedWriter(stdout_file.writer());
    const stdout = stdout_bw.writer();

    try stdout.print("Hello, world!\n", .{});

    try stdout_bw.flush();
}
