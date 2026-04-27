const std = @import("std");
const Io = std.Io;
const EnumSet = std.EnumSet;

pub const Token = struct {
    kind: Kind,
    lexeme: []const u8,

    const Self = @This();

    pub fn format(self: *const Self, writer: *Io.Writer) !void {
        if (self.kind == .whitespace) {
            try writer.print("{s:>16}; {any}", .{ @tagName(self.kind), self.lexeme });
        } else {
            try writer.print("{s:>16}; \"{s}\"", .{ @tagName(self.kind), self.lexeme });
        }
    }

    pub const Kind = enum {
        // Single-character tokens.
        left_parenthesis,
        right_parenthesis,
        left_curly_brace,
        right_curly_brace,
        comma,
        dot,
        minus,
        plus,
        semicolon,
        slash,
        asterisk,

        // One or two character tokens.
        bang,
        bang_equal,
        equal,
        equal_equal,
        greater,
        greater_equal,
        less,
        less_equal,

        // Literals.
        identifier,
        string,
        number,

        // Keywords.
        @"and",
        class,
        @"else",
        false,
        fun,
        @"for",
        @"if",
        nil,
        @"or",
        print,
        @"return",
        super,
        this,
        true,
        @"var",
        @"while",

        // Other
        whitespace,
        comment,
        end_of_file,
        unrecognized,

        pub const keywords = EnumSet(Token.Kind).initMany(&.{
            .@"and",
            .class,
            .@"else",
            .false,
            .fun,
            .@"for",
            .@"if",
            .nil,
            .@"or",
            .print,
            .@"return",
            .super,
            .this,
            .true,
            .@"var",
            .@"while",
        });

        pub const equality_operators = EnumSet(Token.Kind).initMany(&.{ .bang_equal, .equal_equal });
        pub const comparison_operators = EnumSet(Token.Kind).initMany(&.{
            .less,
            .less_equal,
            .greater,
            .greater_equal,
        });
        pub const term_operators = EnumSet(Token.Kind).initMany(&.{
            .plus,
            .minus,
        });
        pub const factor_operators = EnumSet(Token.Kind).initMany(&.{
            .asterisk,
            .slash,
        });
        pub const unary_operators = EnumSet(Token.Kind).initMany(&.{
            .bang,
            .minus,
        });
        pub const literal_values = EnumSet(Token.Kind).initMany(&.{
            .false,
            .true,
            .nil,
            .number,
            .string,
        });
    };
};

test "F" {
    std.debug.print("\n", .{});
    var keywords = Token.Kind.keywords.iterator();
    while (keywords.next()) |keyword| {
        const s = @tagName(keyword);
        std.debug.print("{s}\n", .{s});
    }
}
