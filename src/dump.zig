const std = @import("std");
const cfg = @import("config.zig");
const xxzfmt = @import("fmt.zig");

pub fn normal(
    in_stream: anytype,
    out_stream: anytype,
    config: cfg.Config,
) !void {
    const buf_size = @as(usize, cfg.Config.max_octets_per_line) + 1;
    var buf: [buf_size]u8 = undefined;

    var bufs = buf[0..config.octets_per_line];

    const group_count: u32 = config.octets_per_line / config.octets_per_group +
        @intFromBool(config.octets_per_line % config.octets_per_group != 0);

    var line: usize = 0;
    while (true) : (line += 1) {
        const bytes_read = in_stream.read(bufs) catch |err| return err;
        if (bytes_read == 0)
            break;

        // Line offset.
        try out_stream.print("{x:0>8}: ", .{line * config.octets_per_line});

        // Hex dump.
        var group: usize = 0;
        while (group * config.octets_per_group < bytes_read) : (group += 1) {
            const start = group * config.octets_per_group;
            const end = @min(start + config.octets_per_group, bytes_read);
            try out_stream.print("{}", .{xxzfmt.fmtSliceHexLower(bufs[start..end])});
            if (end < bytes_read)
                try out_stream.writeByte(' ');
        }

        const padding: usize = 2 * (config.octets_per_line - bytes_read + 1) + group_count - group;
        try out_stream.writeByteNTimes(' ', padding);

        // Corresponding text.
        for (bufs[0..bytes_read]) |c|
            try out_stream.writeByte(if (c == '\n') '.' else c);
        try out_stream.writeByte('\n');
    }
}
