const std = @import("std");
const Io = std.Io;

pub const Token = struct {
    kind: Kind,
    lexeme: []const u8,

    const Self = @This();

    pub fn format(self: *const Self, writer: *Io.Writer) !void {
        if (self.kind == .Whitespace) {
            try writer.print("{s:>16}; {any}", .{ @tagName(self.kind), self.lexeme });
        } else {
            try writer.print("{s:>16}; \"{s}\"", .{ @tagName(self.kind), self.lexeme });
        }
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
        EndOfFile,
        Unrecognized,

        pub const Keyword = struct {
            kind: Token.Kind,
            lexeme: []const u8,

            pub fn init(kind: Token.Kind, lexeme: []const u8) @This() {
                return .{ .kind = kind, .lexeme = lexeme };
            }
        };
        pub const keywords: [16]Keyword = .{
            .init(.And, "and"),
            .init(.Class, "class"),
            .init(.Else, "else"),
            .init(.False, "false"),
            .init(.Fun, "fun"),
            .init(.For, "for"),
            .init(.If, "if"),
            .init(.Nil, "nil"),
            .init(.Or, "or"),
            .init(.Print, "print"),
            .init(.Return, " return"),
            .init(.Super, "super"),
            .init(.This, "this"),
            .init(.True, "true"),
            .init(.Var, "var"),
            .init(.While, "while"),
        };
    };
};
