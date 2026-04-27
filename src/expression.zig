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
        };
    };

    pub const Grouping = *Self;

    /// Caller owns the returned slice; it must be freed with the same allocator.
    pub fn toStringAlloc(
        self: *const Self,
        allocator: Allocator,
    ) Allocator.Error![]u8 {
        return expressionToPolishNotationAlloc(allocator, self);
    }
};

fn operatorName(operator: anytype) []const u8 {
    const Operator = @TypeOf(operator);
    return if (Operator == Expression.Unary.Operator)
        switch (operator) {
            .minus => "-",
            .bang => "!",
        }
    else if (Operator == Expression.Binary.Operator)
        switch (operator) {
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
        }
    else
        @compileError("expression.operatorName only supports Expression.Unary.Operator, Expression.Binary.Operator");
}

/// Caller owns the returned slice; it must be freed with the same allocator.
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
        const s = try expressionToPolishNotationAlloc(allocator, expression);
        defer allocator.free(s);
        try output.appendSlice(allocator, s);
    }
    try output.append(allocator, ')');
    return output.toOwnedSlice(allocator);
}

/// Caller owns the returned slice; it must be freed with the same allocator.
pub fn expressionToPolishNotationAlloc(
    allocator: Allocator,
    expression: *const Expression,
) Allocator.Error![]u8 {
    var output = ArrayList(u8).empty;
    defer output.deinit(allocator);

    const s = switch (expression.*) {
        .literal => |token| token.lexeme,
        .unary => |unary| try parenthesize(
            allocator,
            operatorName(unary.operator),
            &.{unary.right_operator},
        ),
        .binary => |binary| try parenthesize(
            allocator,
            operatorName(binary.operator),
            &.{ binary.left_operand, binary.right_operator },
        ),
        .grouping => |inner| try parenthesize(
            allocator,
            "group",
            &.{inner},
        ),
    };
    defer if (expression.* != .literal) allocator.free(s);
    try output.appendSlice(allocator, s);

    return output.toOwnedSlice(allocator);
}

test "Expression.toStringAlloc" {
    _ = Expression;
    _ = Expression.toStringAlloc;
    const expr = Expression{
        .binary = .{
            .left_operand = a0: {
                var expr = Expression{
                    .unary = .{
                        .operator = .minus,
                        .right_operator = a1: {
                            var expr_ = Expression{
                                .literal = .{
                                    .kind = .number,
                                    .lexeme = "123",
                                },
                            };
                            break :a1 &expr_;
                        },
                    },
                };
                break :a0 &expr;
            },
            .operator = .multiply,
            .right_operator = a2: {
                var expr = Expression{
                    .grouping = a3: {
                        var expr = Expression{
                            .literal = .{
                                .kind = .number,
                                .lexeme = "45.67",
                            },
                        };
                        break :a3 &expr;
                    },
                };
                break :a2 &expr;
            },
        },
    };
    const expected = "(* (- 123) (group 45.67))";
    const actual = try expr.toStringAlloc(std.testing.allocator);
    defer std.testing.allocator.free(actual);
    std.debug.print("\n\n", .{});
    std.debug.print("expected = {s}\n", .{expected});
    std.debug.print("actual   = {s}\n", .{actual});
    try std.testing.expect(std.mem.eql(u8, expected, actual));
}
