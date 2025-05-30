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
            else => return error.InvalidOption,
        }
    } else {
        if (long_option_map.get(arg)) |option|
            return option
        else
            return error.InvalidOption;
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

const CLOptions = struct {
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

pub fn parse(arg_strs: [][:0]u8) !CLOptions {
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
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return error.MissingOptionArgument;
                    options.columns = std.fmt.parseInt(u32, next, 10) catch return error.ExpectedUnsigned;
                    idx += 1;
                },
                .capitalize => options.capitalize = true,
                .decimal_offsets => options.decimal_offsets = true,
                .ebcdic => options.ebcdic = true,
                .little_endian => options.little_endian = true,
                .group_size => {
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return error.MissingOptionArgument;
                    options.group_size = std.fmt.parseInt(u32, next, 10) catch return error.ExpectedUnsigned;
                    idx += 1;
                },
                .help => options.help = true,
                .include => options.include = true,
                .length => {
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return error.MissingOptionArgument;
                    options.length = std.fmt.parseInt(u32, next, 10) catch return error.ExpectedUnsigned;
                    idx += 1;
                },
                .name => {
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return error.MissingOptionArgument;
                    if (next.len == 0 or next[0] == '-')
                        return error.MissingOptionArgument;
                    options.name = next;
                    idx += 1;
                },
                .offset => {
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return error.MissingOptionArgument;
                    options.offset = std.fmt.parseInt(i32, next, 10) catch return error.ExpectedSigned;
                    idx += 1;
                },
                .postscript => options.postscript = true,
                .revert => options.revert = true,
                .colorize_mode => {
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return error.MissingOptionArgument;
                    if (when_map.get(next)) |value|
                        options.colorize_mode = value
                    else
                        return error.InvalidColorizeMode;
                },
                .seek => {
                    const next = if (idx < arg_strs.len - 1) arg_strs[idx + 1] else return error.MissingOptionArgument;
                    if (next[0] == '+' or next[0] == '-') {
                        const value = std.fmt.parseInt(i32, next, 10) catch return error.ExpectedSigned;
                        options.seek = SeekOffset{ .relative = value };
                        idx += 1;
                    } else {
                        const value = std.fmt.parseInt(u32, next, 10) catch return error.ExpectedUnsigned;
                        options.seek = SeekOffset{ .absolute = value };
                        idx += 1;
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
                return error.InvalidFileArguments;
        }
    }

    return options;
}
