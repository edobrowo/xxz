const std = @import("std");
const com = @import("common.zig");

fn BinarySlice() type {
    return struct {
        pub fn format(
            bytes: []const u8,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            var buf: [8]u8 = undefined;
            for (bytes) |c| {
                buf[0] = ((c >> 7) & 1) + '0';
                buf[1] = ((c >> 6) & 1) + '0';
                buf[2] = ((c >> 5) & 1) + '0';
                buf[3] = ((c >> 4) & 1) + '0';
                buf[4] = ((c >> 3) & 1) + '0';
                buf[5] = ((c >> 2) & 1) + '0';
                buf[6] = ((c >> 1) & 1) + '0';
                buf[7] = (c & 1) + '0';
                try writer.writeAll(&buf);
            }
        }
    };
}

const formatSliceBinary = BinarySlice().format;

pub fn fmtSliceBinary(bytes: []const u8) std.fmt.Formatter(formatSliceBinary) {
    return .{ .data = bytes };
}

fn HexSlice(
    comptime style: com.DisplayStyle,
    comptime case: com.Case,
) type {
    const charset = "0123456789" ++ if (case == .lower) "abcdef" else "ABCDEF";

    return struct {
        pub fn format(
            bytes: []const u8,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            switch (style) {
                .normal, .postscript => {
                    var buf: [2]u8 = undefined;
                    for (bytes) |c| {
                        buf[0] = charset[c >> 4];
                        buf[1] = charset[c & 0xF];
                        try writer.writeAll(&buf);
                    }
                },
                .c_include => {
                    var buf: [6]u8 = undefined;
                    buf[0] = '0';
                    buf[1] = 'x';
                    buf[4] = ',';
                    buf[5] = ' ';
                    for (bytes) |c| {
                        buf[2] = charset[c >> 4];
                        buf[3] = charset[c & 0xF];
                        try writer.writeAll(&buf);
                    }
                },
                .little_endian => {
                    var buf: [2]u8 = undefined;
                    for (bytes.len - 1..0) |i| {
                        const c = bytes[i];
                        buf[0] = charset[c >> 4];
                        buf[1] = charset[c & 0xF];
                        try writer.writeAll(&buf);
                    }
                },
            }
        }
    };
}

const formatSliceHexLower = HexSlice(.normal, .lower).format;
const formatSliceHexUpper = HexSlice(.normal, .upper).format;
const formatSliceHexPostscript = HexSlice(.postscript, .lower).format;
const formatSliceHexCInclude = HexSlice(.c_include, .lower).format;
const formatSliceHexLE = HexSlice(.little_endian, .lower).format;

pub fn fmtSliceHexLower(bytes: []const u8) std.fmt.Formatter(formatSliceHexLower) {
    return .{ .data = bytes };
}

pub fn fmtSliceHexUpper(bytes: []const u8) std.fmt.Formatter(formatSliceHexUpper) {
    return .{ .data = bytes };
}

pub fn fmtSliceHexPostscript(bytes: []const u8) std.fmt.Formatter(formatSliceHexPostscript) {
    return .{ .data = bytes };
}

pub fn fmtSliceHexCInclude(bytes: []const u8) std.fmt.Formatter(formatSliceHexCInclude) {
    return .{ .data = bytes };
}

pub fn fmtSliceHexLE(bytes: []const u8) std.fmt.Formatter(formatSliceHexLE) {
    return .{ .data = bytes };
}
