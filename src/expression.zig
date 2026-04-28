const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ascii = std.ascii;
const EnumSet = std.EnumSet;

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
        operator: Token,
        right_operand: *Self,
    };

    pub const Binary = struct {
        operator: Token,
        left_operand: *Self,
        right_operand: *Self,
    };

    pub const Grouping = *Self;

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .literal => {},
            .unary => |unary| unary.right_operand.deinit(allocator),
            .binary => |binary| {
                binary.left_operand.deinit(allocator);
                binary.right_operand.deinit(allocator);
            },
            .grouping => |inner| inner.deinit(allocator),
        }
        allocator.destroy(self);
    }

    /// Caller owns the returned slice; it must be freed with the same allocator.
    pub fn toPolishNotationAlloc(
        self: *const Self,
        allocator: Allocator,
    ) Allocator.Error![]u8 {
        return expressionToPolishNotationAlloc(allocator, self);
    }
};

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
            unary.operator.lexeme,
            &.{unary.right_operand},
        ),
        .binary => |binary| try parenthesize(
            allocator,
            binary.operator.lexeme,
            &.{ binary.left_operand, binary.right_operand },
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

test "Expression.expressionToPolishNotationAlloc" {
    _ = Expression;
    _ = Expression.expressionToPolishNotationAlloc;
    const expr = Expression{
        .binary = .{
            .left_operand = a0: {
                var expr = Expression{
                    .unary = .{
                        .operator = .minus,
                        .right_operand = a1: {
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
            .right_operand = a2: {
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
    const actual = try expr.expressionToPolishNotationAlloc(std.testing.allocator);
    defer std.testing.allocator.free(actual);
    std.debug.print("\n\n", .{});
    std.debug.print("expected = {s}\n", .{expected});
    std.debug.print("actual   = {s}\n", .{actual});
    try std.testing.expect(std.mem.eql(u8, expected, actual));
}
