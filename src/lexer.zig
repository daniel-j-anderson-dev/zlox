const std = @import("std");
const ascii = std.ascii;

const zlox = @import("root.zig");
const Token = zlox.Token;

pub const Lexer = struct {
    source: []const u8,
    lexeme_start: usize,
    lexeme_end: usize,
    line_number: usize,
    end_of_file_emitted: bool,

    const Self = @This();

    pub fn init(source: []const u8) Self {
        return .{
            .source = source,
            .lexeme_start = 0,
            .lexeme_end = 0,
            .line_number = 1,
            .end_of_file_emitted = false,
        };
    }

    pub fn next(self: *Self) !?Token {
        if (self.outOfSourceBytes()) {
            return if (self.end_of_file_emitted)
                null
            else a: {
                self.end_of_file_emitted = true;
                break :a .{
                    .kind = .EndOfFile,
                    .lexeme = "",
                };
            };
        }

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
                '!' => if (self.extendLexemeIfCurrentByte(isEqual('='))) .BangEqual else .Bang,
                '=' => if (self.extendLexemeIfCurrentByte(isEqual('='))) .EqualEqual else .Equal,
                '<' => if (self.extendLexemeIfCurrentByte(isEqual('='))) .LessEqual else .Less,
                '>' => if (self.extendLexemeIfCurrentByte(isEqual('='))) .GreaterEqual else .Greater,
                '/' => if (self.extendLexemeIfCurrentByte(isEqual('/'))) a: {
                    self.extendLexemeWhileCurrentByte(not(isEqual('\n')));
                    break :a .Comment;
                } else .Slash,
                '\n' => a: {
                    self.nextLine();
                    break :a .Whitespace;
                },
                ' ', '\t', '\r', ascii.control_code.vt, ascii.control_code.ff => a: {
                    self.extendLexemeWhileCurrentByte(isElementOf(non_new_line_whitespace));
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
                'A'...'Z', 'a'...'z', '_' => a: {
                    if (self.extendedLexemeToKeyword()) |keyword_kind| {
                        break :a keyword_kind;
                    }
                    self.extendLexemeWhileCurrentByte(Or(ascii.isAlphanumeric, isEqual('_')));
                    break :a .Identifier;
                },
                else => a: {
                    self.extendLexemeWhileCurrentByte(not(isElementOf(recognized)));
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
        self.extendLexemeWhileCurrentByte(not(isEqual('"')));
        const is_closing_quote_present = self.extendLexemeIfCurrentByte(isEqual('"'));

        if (!is_closing_quote_present)
            return error.UnterminatedStringLiteral;

        const new_line_count = std.mem.count(u8, self.lexeme(), "\n");
        self.line_number +|= new_line_count;
    }

    fn extendLexemeToNumberLiteral(self: *Self) void {
        self.extendLexemeWhileCurrentByte(ascii.isDigit);
        if (self.extendLexemeIfCurrentByte(isEqual('.'))) {
            self.extendLexemeWhileCurrentByte(ascii.isDigit);
        }
    }

    fn extendedLexemeToKeyword(self: *Self) ?Token.Kind {
        self.extendLexemeWhileCurrentByte(ascii.isAlphabetic);
        for (Token.Kind.keywords) |keyword| {
            const is_lexeme_keyword = std.mem.eql(u8, keyword.lexeme, self.lexeme());
            if (is_lexeme_keyword) return keyword.kind;
        }
        return null;
    }
};

fn isEqual(a: u8) fn (u8) bool {
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

fn Or(predicate_a: fn (u8) bool, predicate_b: fn (u8) bool) fn (u8) bool {
    return struct {
        pub fn f(a: u8) bool {
            return predicate_a(a) or predicate_b(a);
        }
    }.f;
}

fn isElementOf(haystack: []const u8) fn (u8) bool {
    return struct {
        pub fn f(needle: u8) bool {
            return std.mem.findScalar(u8, haystack, needle) != null;
        }
    }.f;
}

const non_new_line_whitespace: *const [5]u8 = &.{ ' ', '\t', '\r', ascii.control_code.vt, ascii.control_code.ff };
const recognized = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz<>./-=!(){}*;\"" ++ non_new_line_whitespace;
