const std = @import("std");
const cfg = @import("config.zig");
const xxzfmt = @import("fmt.zig");

fn divceil(n: usize, d: usize) usize {
    return n / d + @intFromBool(n % d != 0);
}

pub fn normal(
    in_stream: anytype,
    out_stream: anytype,
    config: cfg.Config,
) !void {
    const buf_size = @as(usize, cfg.Config.max_octets_per_line) + 1;
    var buf: [buf_size]u8 = undefined;

    var bufs = buf[0..config.octets_per_line];

    const group_count: usize = divceil(config.octets_per_line, config.octets_per_group);

    var line: usize = 0;
    while (true) : (line += 1) {
        const bytes_read = in_stream.read(bufs) catch |err| return err;
        if (bytes_read == 0)
            break;

        // Line offset.
        try out_stream.print("{x:0>8}: ", .{line * config.octets_per_line});

        // Hex dump.
        try out_stream.print("{}", .{xxzfmt.fmtGroupsHexLower(bufs[0..bytes_read], config.octets_per_group)});

        // Padding.
        const empty_groups = group_count - divceil(bytes_read, config.octets_per_group);
        const padding: usize = 2 * (config.octets_per_line - bytes_read + 1) + empty_groups;
        try out_stream.writeByteNTimes(' ', padding);

        // Corresponding text.
        for (bufs[0..bytes_read]) |c|
            try out_stream.writeByte(if (c == '\n') '.' else c);
        try out_stream.writeByte('\n');
    }
}
