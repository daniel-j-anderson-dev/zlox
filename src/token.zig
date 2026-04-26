const std = @import("std");
const Io = std.Io;

pub const Token = struct {
    kind: Kind,
    lexeme: []const u8,

    const Self = @This();

    pub fn format(self: *const Self, writer: Io.Writer) !void {
        writer.print("{any:>16}; \"{s}\"", .{ self.kind, self.lexeme });
    }

    pub const Kind = enum {
        // Single-character tokens.
        LeftParenthesis,
        RightParenthesis,
        LeftCurlyBrace,
        RightCurlyBrace,
        Comma,
        Dot,
        Minus,
        Plus,
        Semicolon,
        Slash,
        Asterisk,

        // One or two character tokens.
        Bang,
        BangEqual,
        Equal,
        EqualEqual,
        Greater,
        GreaterEqual,
        Less,
        LessEqual,

        // Literals.
        Identifier,
        String,
        Number,

        // Keywords.
        And,
        Class,
        Else,
        False,
        Fun,
        For,
        If,
        Nil,
        Or,
        Print,
        Return,
        Super,
        This,
        True,
        Var,
        While,

        // Other
        Whitespace,
        Comment,
        Eof,
        Unrecognized,
    };
};
