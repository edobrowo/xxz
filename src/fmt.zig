const std = @import("std");
const com = @import("common.zig");

fn BinaryGroups() type {
    return struct {
        const Self = @This();

        bytes: []const u8,
        group_size: u32,

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            var group: usize = 0;
            while (group * self.group_size < self.bytes.len) : (group += 1) {
                const start = group * self.group_size;
                const end = @min(start + self.group_size, self.bytes.len);

                var buf: [8]u8 = undefined;
                for (self.bytes[start..end]) |c| {
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

                if (end < self.bytes.len)
                    try writer.writeByte(' ');
            }
        }
    };
}

const formatGroupsBinary = BinaryGroups().format;

pub fn fmtGroupsBinary(bytes: []const u8, group_size: u32) std.fmt.Formatter(formatGroupsBinary) {
    return .{ .data = BinaryGroups(){ .bytes = bytes, .group_size = group_size } };
}

fn HexGroups(comptime case: com.Case) type {
    const charset = "0123456789" ++ if (case == .lower) "abcdef" else "ABCDEF";

    return struct {
        const Self = @This();

        bytes: []const u8,
        group_size: u32,

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            var group: usize = 0;
            while (group * self.group_size < self.bytes.len) : (group += 1) {
                const start = group * self.group_size;
                const end = @min(start + self.group_size, self.bytes.len);

                var buf: [2]u8 = undefined;
                for (self.bytes[start..end]) |c| {
                    buf[0] = charset[c >> 4];
                    buf[1] = charset[c & 0xF];
                    try writer.writeAll(&buf);
                }

                if (end < self.bytes.len)
                    try writer.writeByte(' ');
            }
        }
    };
}

const formatGroupsHexLower = HexGroups(.lower).format;
const formatGroupsHexUpper = HexGroups(.upper).format;

pub fn fmtGroupsHexLower(bytes: []const u8, group_size: u32) std.fmt.Formatter(formatGroupsHexLower) {
    return .{ .data = HexGroups(.lower){ .bytes = bytes, .group_size = group_size } };
}

pub fn fmtGroupsHexUpper(bytes: []const u8, group_size: u32) std.fmt.Formatter(formatGroupsHexUpper) {
    return .{ .data = HexGroups(.upper){ .bytes = bytes, .group_size = group_size } };
}

fn Postscript() type {
    const charset = "0123456789abcdef";

    return struct {
        pub fn format(
            bytes: []const u8,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            var buf: [2]u8 = undefined;
            for (bytes) |c| {
                buf[0] = charset[c >> 4];
                buf[1] = charset[c & 0xF];
                try writer.writeAll(&buf);
            }
        }
    };
}

const formatPostscript = Postscript().format;

pub fn fmtPostscript(bytes: []const u8) std.fmt.Formatter(formatPostscript) {
    return .{ .data = bytes };
}

fn CInclude(comptime case: com.Case) type {
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

            var buf: [6]u8 = undefined;
            buf[0] = '0';
            buf[1] = if (case == .lower) 'x' else 'X';
            buf[4] = ',';
            buf[5] = ' ';
            for (bytes) |c| {
                buf[2] = charset[c >> 4];
                buf[3] = charset[c & 0xF];
                try writer.writeAll(&buf);
            }
        }
    };
}

const formatCIncludeLower = CInclude(.lower).format;
const formatCIncludeUpper = CInclude(.upper).format;

pub fn fmtCIncludeLower(bytes: []const u8) std.fmt.Formatter(formatCIncludeLower) {
    return .{ .data = bytes };
}

pub fn fmtCIncludeUpper(bytes: []const u8) std.fmt.Formatter(formatCIncludeUpper) {
    return .{ .data = bytes };
}

fn LEHexGroups() type {
    const charset = "0123456789abcdef";

    return struct {
        const Self = @This();

        bytes: []const u8,
        group_size: u32,

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            var group: usize = 0;
            while (group * self.group_size < self.bytes.len) : (group += 1) {
                const start = group * self.group_size;
                const end = @min(start + self.group_size, self.bytes.len);

                var buf: [2]u8 = undefined;
                for (self.bytes.len - 1..0) |i| {
                    const c = self.bytes[i];
                    buf[0] = charset[c >> 4];
                    buf[1] = charset[c & 0xF];
                    try writer.writeAll(&buf);
                }

                if (end < self.bytes.len)
                    try writer.writeByte(' ');
            }
        }
    };
}

const formatGroupsLEHex = LEHexGroups().format;

pub fn fmtGroupsLEHex(bytes: []const u8, group_size: u32) std.fmt.Formatter(formatGroupsLEHex) {
    return .{ .data = LEHexGroups(){ .bytes = bytes, .group_size = group_size } };
}
