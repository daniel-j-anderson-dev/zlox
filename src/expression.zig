const std = @import("std");
const ascii = std.ascii;

const zlox = @import("root.zig");
const Token = zlox.Token;
const Lexer = zlox.Lexer;

pub const Expression = union(enum) {
    literal: Literal,
    unary: Unary,
    binary: Binary,
    grouping: Grouping,

    pub const Literal = Token;

    pub const Unary = struct {
        operator: Operator,
        right_hand_side: *Expression,

        pub const Operator = enum {
            minus,
            bang,
        };
    };

    pub const Binary = struct {
        operator: Operator,
        left_hand_side: *Expression,
        right_hand_side: *Expression,

        pub const Operator = enum {
            equal_equal,
            bang_equal,
            less,
            less_equal,
            greater,
            greater_equal,
        };
    };

    pub const Grouping = *Expression;
};
