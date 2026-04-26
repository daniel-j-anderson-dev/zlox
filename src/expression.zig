const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ascii = std.ascii;

const zlox = @import("root.zig");
const Token = zlox.Token;
const Lexer = zlox.Lexer;

pub const Expression = union(enum) {
    literal: Literal,
    unary: Unary,
    binary: Binary,
    grouping: Grouping,

    const Self = @This();

    pub const Literal = Token;

    pub const Unary = struct {
        operator: Operator,
        right_operator: *Self,

        pub const Operator = enum {
            minus,
            bang,

            pub fn name(self: @This()) []const u8 {
                return switch (self) {
                    .minus => "-",
                    .bang => "!",
                };
            }
        };
    };

    pub const Binary = struct {
        operator: Operator,
        left_operand: *Self,
        right_operator: *Self,

        pub const Operator = enum {
            equal,
            not_equal,
            less_than,
            less_than_or_equal,
            greater_than,
            greater_than_or_equal,
            add,
            subtract,
            multiply,
            divide,

            pub fn name(self: @This()) []const u8 {
                return switch (self) {
                    .equal => "==",
                    .not_equal => "!=",
                    .less_than => "<",
                    .less_than_or_equal => "<=",
                    .greater_than => ">=",
                    .greater_than_or_equal => ">",
                    .add => "+",
                    .subtract => "-",
                    .multiply => "*",
                    .divide => "/",
                };
            }
        };
    };

    pub const Grouping = *Self;

    pub fn toString(
        self: *const Self,
        allocator: Allocator,
    ) Allocator.Error![]u8 {
        var output = ArrayList(u8).empty;
        defer output.deinit(allocator);

        switch (self.*) {
            .literal => |token| {
                try output.appendSlice(allocator, token.lexeme);
            },
            .unary => |unary| {
                const s = try parenthesize(
                    allocator,
                    unary.operator.name(),
                    &.{unary.right_operator},
                );
                defer allocator.free(s);
                try output.appendSlice(allocator, s);
            },
            .binary => |binary| {
                const s = try parenthesize(
                    allocator,
                    binary.operator.name(),
                    &.{ binary.left_operand, binary.right_operator },
                );
                defer allocator.free(s);
                try output.appendSlice(allocator, s);
            },
            .grouping => |inner| {
                const s = try inner.toString(allocator);
                defer allocator.free(s);
                try output.appendSlice(allocator, "(group ");
                try output.appendSlice(allocator, s);
                try output.append(allocator, ')');
            },
        }

        return output.toOwnedSlice(allocator);
    }

    fn parenthesize(
        allocator: Allocator,
        name: []const u8,
        expressions: []const *const Expression,
    ) Allocator.Error![]u8 {
        var output = ArrayList(u8).empty;
        defer output.deinit(allocator);

        try output.append(allocator, '(');
        try output.appendSlice(allocator, name);
        for (expressions) |expression| {
            try output.append(allocator, ' ');
            const s = try expression.toString(allocator);
            defer allocator.free(s);
            try output.appendSlice(allocator, s);
        }
        try output.append(allocator, ')');
        return output.toOwnedSlice(allocator);
    }
};

test "Expression.toString" {
    _ = Expression;
    _ = Expression.toString;
    const e = Expression{
        .binary = .{
            .left_operand = a: {
                var expr = Expression{
                    .unary = .{
                        .operator = .minus,
                        .right_operator = b: {
                            var e = Expression{
                                .literal = .{
                                    .kind = .Number,
                                    .lexeme = "123",
                                },
                            };
                            break :b &e;
                        },
                    },
                };
                break :a &expr;
            },
            .operator = .multiply,
            .right_operator = c: {
                var expr = Expression{
                    .grouping = d: {
                        var expr = Expression{
                            .literal = .{
                                .kind = .Number,
                                .lexeme = "45.67",
                            },
                        };
                        break :d &expr;
                    },
                };
                break :c &expr;
            },
        },
    };
    const expected = "(* (- 123) (group 45.67))";
    const actual = try e.toString(std.testing.allocator);
    defer std.testing.allocator.free(actual);
    std.debug.print("\n\n", .{});
    std.debug.print("expected = {s}\n", .{expected});
    std.debug.print("actual   = {s}\n", .{actual});
    try std.testing.expect(std.mem.eql(u8, expected, actual));
}
