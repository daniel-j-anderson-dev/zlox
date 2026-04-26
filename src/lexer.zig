const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log;

const zlox = @import("root.zig");

pub const Lexer = struct {
    source: []const u8,
    lexeme_start: usize,
    lexeme_end: usize,
    line_number: usize,

    const Self = @This();

    pub fn init(source: []const u8) Self {
        return .{
            .source = source,
            .lexeme_start = 0,
            .lexeme_end = 0,
            .line_number = 0,
        };
    }
};
