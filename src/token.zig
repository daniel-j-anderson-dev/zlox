const std = @import("std");
const Io = std.Io;
const EnumSet = std.EnumSet;
const trim = std.mem.trim;
const ascii = std.ascii;

pub const Token = struct {
    kind: Kind,
    lexeme: []const u8,
    line_number: usize,

    const Self = @This();

    pub fn format(self: *const Self, writer: *Io.Writer) !void {
        try writer.print("ln: {d:>3}; {s:>" ++ Token.Kind.longest_field_name_length_string ++ "}; ", .{ self.line_number, @tagName(self.kind) });

        switch (self.kind) {
            .whitespace => try writer.print("{any}", .{self.lexeme}),
            .comment => try writer.print("{s}", .{trim(u8, self.lexeme, &ascii.whitespace)}),
            else => try writer.print("{s}", .{self.lexeme}),
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

        pub const non_semantic = EnumSet(Token.Kind).initMany(&.{
            .comment,
            .whitespace,
            .unrecognized,
        });
        pub const semantic = Token.Kind.non_semantic.complement();

        pub const equality_operators = EnumSet(Token.Kind).initMany(&.{
            .bang_equal,
            .equal_equal,
        });
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

        const longest_field_name_length = a: {
            var max = 0;
            for (@typeInfo(Token.Kind).@"enum".fields) |tk|
                max = @max(max, tk.name.len);
            break :a max;
        };

        const longest_field_name_length_string = std.fmt.comptimePrint("{d}", .{longest_field_name_length});
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

test "Token.Kind.longest_field_name_length" {
    std.debug.print("\n\n{d}\n\n", .{Token.Kind.longest_field_name_length});
}
