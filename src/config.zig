const std = @import("std");
const clap = @import("clap.zig");
const com = @import("common.zig");

fn areOptionsCompatible(cl_options: clap.CLOptions) bool {
    var incompat_count: u32 = @intFromBool(cl_options.bits);
    incompat_count += @intFromBool(cl_options.little_endian);
    incompat_count += @intFromBool(cl_options.uppercase);
    incompat_count += @intFromBool(cl_options.postscript);
    incompat_count += @intFromBool(cl_options.include);

    return incompat_count < 2;
}

fn resolveMode(cl_options: clap.CLOptions) com.Mode {
    return if (cl_options.revert) .reverse else .forward;
}

fn resolveDisplayStyle(cl_options: clap.CLOptions) com.DisplayStyle {
    return if (cl_options.postscript)
        .postscript
    else if (cl_options.include)
        .c_include
    else if (cl_options.little_endian)
        .little_endian
    else
        .normal;
}

fn resolveDigitEncoding(cl_options: clap.CLOptions) com.DigitEncoding {
    return if (cl_options.bits) .binary else .hex;
}

fn resolveTextEncoding(cl_options: clap.CLOptions) com.TextEncoding {
    return if (cl_options.ebcdic) .ebcdic else .ascii;
}

fn resolveOffsetStyle(cl_options: clap.CLOptions) com.OffsetStyle {
    return if (cl_options.decimal_offsets) .decimal else .hex;
}

fn resolveCase(cl_options: clap.CLOptions, style: com.DisplayStyle) com.Case {
    if ((style == .c_include and cl_options.capitalize) or
        (style != .c_include and cl_options.uppercase))
        return .upper
    else
        return .lower;
}

fn defaultOctetsPerLine(style: com.DisplayStyle) u32 {
    return switch (style) {
        .normal => 16,
        .postscript => 30,
        .c_include => 12,
        .little_endian => 16,
    };
}

fn defaultOctetsPerGroup(style: com.DisplayStyle) u32 {
    return switch (style) {
        .normal => 2,
        .postscript => 2,
        .c_include => 2,
        .little_endian => 4,
    };
}

fn toVariableName(allocator: std.mem.Allocator, file_name: []const u8) ![]u8 {
    var buf = try allocator.alloc(u8, file_name.len);
    for (file_name, 0..) |c, i| {
        buf[i] = if (c != '.') c else '_';
    }
    return buf;
}

fn resolveVariableName(allocator: std.mem.Allocator, cl_options: clap.CLOptions) ![]u8 {
    return cl_options.name orelse
        if (cl_options.in_file) |file_name|
            try toVariableName(allocator, file_name)
        else
            "";
}

pub const Config = struct {
    const Self = @This();

    mode: com.Mode,

    read_start: com.SeekOffset,
    read_length: ?u32,

    display_style: com.DisplayStyle,
    digit_encoding: com.DigitEncoding,
    text_encoding: com.TextEncoding,
    offset_style: com.OffsetStyle,

    case: com.Case,
    octets_per_line: u32,
    octets_per_group: u32,
    displayed_offset: i32,
    autoskip: bool,
    c_include_variable_name: []u8,
    colorize_mode: com.When,

    pub fn init(allocator: std.mem.Allocator, cl_options: clap.CLOptions) !Config {
        var config: Config = undefined;

        if (!areOptionsCompatible(cl_options))
            return error.IncompatableOptions;

        config.mode = resolveMode(cl_options);

        config.read_start = cl_options.seek orelse com.SeekOffset{ .absolute = 0 };
        config.read_length = cl_options.length;

        config.display_style = resolveDisplayStyle(cl_options);
        config.digit_encoding = resolveDigitEncoding(cl_options);
        config.text_encoding = resolveTextEncoding(cl_options);
        config.offset_style = resolveOffsetStyle(cl_options);

        config.case = resolveCase(cl_options, config.display_style);
        config.octets_per_line = cl_options.columns orelse defaultOctetsPerLine(config.display_style);
        config.octets_per_group = cl_options.group_size orelse defaultOctetsPerGroup(config.display_style);
        config.displayed_offset = cl_options.offset orelse 0;
        config.autoskip = cl_options.autoskip;
        config.c_include_variable_name = try resolveVariableName(allocator, cl_options);
        config.colorize_mode = cl_options.colorize_mode;

        return config;
    }

    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.c_include_variable_name);
    }
};
