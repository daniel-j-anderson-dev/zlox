const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log;
const ascii = std.ascii;

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
                '!' => if (self.extendLexemeIfCurrentByte(is('='))) .BangEqual else .Bang,
                '=' => if (self.extendLexemeIfCurrentByte(is('='))) .EqualEqual else .Equal,
                '<' => if (self.extendLexemeIfCurrentByte(is('='))) .LessEqual else .Less,
                '>' => if (self.extendLexemeIfCurrentByte(is('='))) .GreaterEqual else .Greater,
                '/' => if (self.extendLexemeIfCurrentByte(is('/'))) a: {
                    self.extendLexemeWhileCurrentByte(not(is('\n')));
                    break :a .Comment;
                } else .Slash,
                '\n' => a: {
                    self.nextLine();
                    break :a .Whitespace;
                },
                ' ', '\t', '\r', ascii.control_code.vt, ascii.control_code.ff => a: {
                    self.extendLexemeWhileCurrentByte(isOneOf(non_new_line_whitespace));
                    break :a .Whitespace;
                },
                '"' => a: {
                    try self.extendLexemeToStringLiteral();
                    break :a .String;
                },
                '0'...'9' => a: {
                    self.extendLexemeToNumberLiteral();
                    break :a .Number;
                },
                else => a: {
                    break :a .Unrecognized;
                },
            },
            .lexeme = self.lexeme(),
        };
    }

    fn sourceBytesAvailable(self: *const Self) bool {
        return self.lexeme_end < self.source.len;
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

    fn nextLine(self: *Self) void {
        self.line_number +|= 1;
    }

    fn extendLexemeIfCurrentByte(self: *Self, predicate: fn (u8) bool) bool {
        if (self.sourceBytesAvailable() and predicate(self.currentByte())) {
            self.extendLexeme();
            return true;
        } else {
            return false;
        }
    }

    fn extendLexemeWhileCurrentByte(self: *Self, predicate: fn (u8) bool) void {
        while (self.extendLexemeIfCurrentByte(predicate)) {}
    }

    fn extendLexemeToStringLiteral(self: *Self) !void {
        self.extendLexemeWhileCurrentByte(not(is('"')));
        const is_closing_quote_present = self.extendLexemeIfCurrentByte(is('"'));

        if (!is_closing_quote_present)
            return error.UnterminatedStringLiteral;

        const new_line_count = std.mem.count(u8, self.lexeme(), "\n");
        self.line_number +|= new_line_count;
    }

    fn extendLexemeToNumberLiteral(self: *Self) void {
        self.extendLexemeWhileCurrentByte(ascii.isDigit);
        if (self.extendLexemeIfCurrentByte(is('.'))) {
            self.extendLexemeWhileCurrentByte(ascii.isDigit);
        }
    }
};

fn is(a: u8) fn (u8) bool {
    return struct {
        pub fn f(b: u8) bool {
            return a == b;
        }
    }.f;
}

fn not(predicate: fn (u8) bool) fn (u8) bool {
    return struct {
        pub fn f(a: u8) bool {
            return !predicate(a);
        }
    }.f;
}

fn isOneOf(haystack: []const u8) fn (u8) bool {
    return struct {
        pub fn f(needle: u8) bool {
            return std.mem.findScalar(u8, haystack, needle) != null;
        }
    }.f;
}

const non_new_line_whitespace: *const [5]u8 = &.{ ' ', '\t', '\r', ascii.control_code.vt, ascii.control_code.ff };
