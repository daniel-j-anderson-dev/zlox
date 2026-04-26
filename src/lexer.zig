const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log;

const zlox = @import("root.zig");
const Token = zlox.Token;

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

    pub fn next(self: *Self) !?Token {
        if (self.outOfSourceBytes()) return null;

        self.startNewLexeme();
        const current = self.currentByte();
        self.extendLexeme();

        return .{
            .kind = switch (current) {
                '(' => .LeftParenthesis,
                ')' => .RightParenthesis,
                '{' => .LeftCurlyBrace,
                '}' => .RightCurlyBrace,
                ',' => .Comma,
                '.' => .Dot,
                '-' => .Minus,
                '+' => .Plus,
                ';' => .Semicolon,
                '*' => .Asterisk,
                else => a: {
                    break :a .Unrecognized;
                },
            },
            .lexeme = self.lexeme(),
        };
    }

    fn outOfSourceBytes(self: *const Self) bool {
        return self.lexeme_end >= self.source.len;
    }

    fn currentByte(self: *const Self) u8 {
        return self.source[self.lexeme_end];
    }

    fn lexeme(self: *const Self) []const u8 {
        return self.source[self.lexeme_start..self.lexeme_end];
    }

    fn startNewLexeme(self: *Self) void {
        self.lexeme_start = self.lexeme_end;
    }

    fn extendLexeme(self: *Self) void {
        self.lexeme_end +|= 1;
    }
};
