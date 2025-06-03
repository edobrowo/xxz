pub const When = enum {
    always,
    auto,
    never,
};

const SeekOffsetKind = enum {
    absolute,
    relative,
};

pub const SeekOffset = union(SeekOffsetKind) {
    absolute: u32,
    relative: i32,
};

pub const Case = enum {
    upper,
    lower,
};

pub const Mode = enum {
    forward,
    reverse,
};

pub const DisplayStyle = enum {
    normal,
    postscript,
    c_include,
    little_endian,
};

pub const DigitEncoding = enum {
    hex,
    binary,
};

pub const TextEncoding = enum {
    ascii,
    ebcdic,
};

pub const OffsetStyle = enum {
    hex,
    decimal,
};
