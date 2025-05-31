const std = @import("std");

const CLOptionKind = enum {
    autoskip,
    bits,
    columns,
    capitalize,
    decimal_offsets,
    ebcdic,
    little_endian,
    group_size,
    help,
    include,
    length,
    name,
    offset,
    postscript,
    revert,
    colorize_mode,
    seek,
    uppercase,
    version,
};

const long_option_map = std.StaticStringMap(CLOptionKind).initComptime(.{
    .{ "autoskip", .autoskip },
    .{ "bits", .bits },
    .{ "cols", .columns },
    .{ "capitalize", .capitalize },
    .{ "EBCDIC", .ebcdic },
    .{ "groupsize", .group_size },
    .{ "help", .help },
    .{ "include", .include },
    .{ "len", .length },
    .{ "name", .name },
    .{ "ps", .postscript },
    .{ "postscript", .postscript },
    .{ "plain", .postscript },
    .{ "revert", .revert },
    .{ "seek", .seek },
    .{ "version", .version },
});

fn isOption(arg: [:0]const u8) bool {
    return arg.len > 1 and arg[0] == '-';
}

fn trimOption(arg: [:0]const u8) [:0]const u8 {
    if (arg[1] == '-')
        return arg[2..]
    else
        return arg[1..];
}

pub const ParseError = error{
    InvalidOption,
    MissingOptionArgument,
    ExpectedUnsignedArgument,
    ExpectedSignedArgument,
    InvalidColorizeMode,
    InvalidFileArguments,
};

fn parseOption(arg: [:0]const u8) !CLOptionKind {
    if (arg.len == 1) {
        switch (arg[0]) {
            'a' => return .autoskip,
            'b' => return .bits,
            'c' => return .columns,
            'C' => return .capitalize,
            'd' => return .decimal_offsets,
            'E' => return .ebcdic,
            'e' => return .little_endian,
            'g' => return .group_size,
            'h' => return .help,
            'i' => return .include,
            'l' => return .length,
            'n' => return .name,
            'o' => return .offset,
            'p' => return .postscript,
            'r' => return .revert,
            'R' => return .colorize_mode,
            's' => return .seek,
            'u' => return .uppercase,
            'v' => return .version,
            else => return ParseError.InvalidOption,
        }
    } else {
        if (long_option_map.get(arg)) |option|
            return option
        else
            return ParseError.InvalidOption;
    }
}

const When = enum {
    always,
    auto,
    never,
};

const when_map = std.StaticStringMap(When).initComptime(.{
    .{ "always", .always },
    .{ "auto", .auto },
    .{ "never", .never },
});

const SeekOffsetKind = enum {
    absolute,
    relative,
};

const SeekOffset = union(SeekOffsetKind) {
    absolute: u32,
    relative: i32,
};

pub const CLOptions = struct {
    autoskip: bool = false,
    bits: bool = false,
    columns: u32 = 16,
    capitalize: bool = false,
    decimal_offsets: bool = false,
    ebcdic: bool = false,
    little_endian: bool = false,
    group_size: u32 = 2,
    help: bool = false,
    include: bool = false,
    length: ?u32 = null,
    name: ?[]u8 = null,
    offset: ?i32 = null,
    postscript: bool = false,
    revert: bool = false,
    colorize_mode: When = .auto,
    seek: ?SeekOffset = null,
    uppercase: bool = false,
    version: bool = false,
    in_file: ?[]u8 = null,
    out_file: ?[]u8 = null,
};

fn getOptionArgument(arg_strs: [][:0]u8, idx: *usize) ![:0]u8 {
    if (idx.* < arg_strs.len - 1) {
        idx.* += 1;
        return arg_strs[idx.*];
    } else return ParseError.MissingOptionArgument;
}

fn parseUnsigned(arg: [:0]u8) !u32 {
    return std.fmt.parseInt(u32, arg, 10) catch return ParseError.ExpectedUnsignedArgument;
}

fn parseSigned(arg: [:0]u8) !i32 {
    return std.fmt.parseInt(i32, arg, 10) catch return ParseError.ExpectedSignedArgument;
}

pub fn parse(arg_strs: [][:0]u8) ParseError!CLOptions {
    var options = CLOptions{};

    var idx: usize = 0;
    while (idx < arg_strs.len) : (idx += 1) {
        const arg_str = arg_strs[idx];
        if (isOption(arg_str)) {
            const option_str = trimOption(arg_str);
            const option = try parseOption(option_str);
            switch (option) {
                .autoskip => options.autoskip = true,
                .bits => options.bits = true,
                .columns => {
                    const next = try getOptionArgument(arg_strs, &idx);
                    options.columns = try parseUnsigned(next);
                },
                .capitalize => options.capitalize = true,
                .decimal_offsets => options.decimal_offsets = true,
                .ebcdic => options.ebcdic = true,
                .little_endian => options.little_endian = true,
                .group_size => {
                    const next = try getOptionArgument(arg_strs, &idx);
                    options.group_size = try parseUnsigned(next);
                },
                .help => options.help = true,
                .include => options.include = true,
                .length => {
                    const next = try getOptionArgument(arg_strs, &idx);
                    options.length = try parseUnsigned(next);
                },
                .name => {
                    const next = try getOptionArgument(arg_strs, &idx);
                    if (next.len == 0 or next[0] == '-')
                        return ParseError.MissingOptionArgument;
                    options.name = next;
                },
                .offset => {
                    const next = try getOptionArgument(arg_strs, &idx);
                    options.offset = try parseSigned(next);
                },
                .postscript => options.postscript = true,
                .revert => options.revert = true,
                .colorize_mode => {
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return ParseError.MissingOptionArgument;
                    if (when_map.get(next)) |value|
                        options.colorize_mode = value
                    else
                        return ParseError.InvalidColorizeMode;
                },
                .seek => {
                    const next = try getOptionArgument(arg_strs, &idx);
                    if (next[0] == '+' or next[0] == '-') {
                        const value = try parseSigned(next);
                        options.seek = SeekOffset{ .relative = value };
                    } else {
                        const value = try parseUnsigned(next);
                        options.seek = SeekOffset{ .absolute = value };
                    }
                },
                .uppercase => options.uppercase = true,
                .version => options.version = true,
            }
        } else {
            if (options.in_file == null)
                options.in_file = arg_str
            else if (options.out_file == null)
                options.out_file = arg_str
            else
                return ParseError.InvalidFileArguments;
        }
    }

    return options;
}
