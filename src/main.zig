const std = @import("std");

pub fn main() !void {
    const file = std.io.getStdIn();
    var br = std.io.bufferedReader(file.reader());
    const in_stream = br.reader();

    var buf: [1024]u8 = undefined;

    const bytes_read = in_stream.readAll(&buf) catch |err| return err;

    const stdout_file = std.io.getStdOut();
    var stdout_bw = std.io.bufferedWriter(stdout_file.writer());
    const stdout = stdout_bw.writer();

    const hex_lower = "0123456789abcdef";

    for (0..bytes_read) |i| {
        const byte = buf[i];

        const high: u8 = (byte & 0xF0) >> 4;
        const low: u8 = byte & 0x0F;

        var hex_str_buf: [4]u8 = undefined;
        hex_str_buf[0] = '0';
        hex_str_buf[1] = 'x';
        hex_str_buf[2] = hex_lower[high];
        hex_str_buf[3] = hex_lower[low];

        try stdout.print("{s},", .{hex_str_buf});
    }
    try stdout.print("\n", .{});

    try stdout_bw.flush();
}
