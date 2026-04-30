const std = @import("std");
const Io = std.Io;
const parseFloat = std.fmt.parseFloat;
const trim = std.mem.trim;

const zlox = @import("root.zig");
const Expression = zlox.Expression;

pub const Value = union(enum) {
    nil,
    boolean: bool,
    number: f64,
    string: []const u8,

    const Self = @This();

    pub fn format(self: *const Self, writer: *Io.Writer) !void {
        try switch (self.*) {
            .nil => writer.print("nil", .{}),
            .boolean => |v| writer.print("{any}", .{v}),
            .number => |v| writer.print("{d}", .{v}),
            .string => |v| writer.print("{s}", .{v}),
        };
    }
};

pub fn evaluate(expression: *const Expression) !Value {
    return switch (expression.*) {
        .literal => |literal| switch (literal.kind) {
            .nil => .{ .nil = void{} },
            .true => .{ .boolean = true },
            .false => .{ .boolean = false },
            .number => .{ .number = try parseFloat(f64, literal.token.lexeme) },
            .string => .{ .string = literal.token.lexeme },
        },
        .grouping => |inner| evaluate(inner),
        .unary => |unary| switch (unary.operator.kind) {
            .arithmetic_negate => switch (try evaluate(unary.right_operand)) {
                .number => |n| .{ .number = -n },
                else => error.UnaryMinusNonNumber,
            },
            .boolean_negate => switch (try evaluate(unary.right_operand)) {
                .boolean => |b| .{ .boolean = !b },
                else => error.UnaryBangNonBoolean,
            },
        },
        .binary => |binary| a: {
            const lhs = try evaluate(binary.left_operand);
            const rhs = try evaluate(binary.right_operand);
            switch (binary.operator.kind) {
                .not_equal => {
                    if (lhs == .boolean and rhs == .boolean)
                        break :a .{ .boolean = lhs.boolean != rhs.boolean };
                    if (lhs == .number and rhs == .number)
                        break :a .{ .boolean = lhs.number != rhs.number };
                    if (lhs == .string and rhs == .string)
                        break :a .{ .boolean = !std.mem.eql(u8, lhs.string, rhs.string) };
                    return error.BangEqualIncompatibleTypes;
                },
                .equal => {
                    if (lhs == .boolean and rhs == .boolean)
                        break :a .{ .boolean = lhs.boolean == rhs.boolean };
                    if (lhs == .number and rhs == .number)
                        break :a .{ .boolean = lhs.number == rhs.number };
                    if (lhs == .string and rhs == .string)
                        break :a .{ .boolean = std.mem.eql(u8, lhs.string, rhs.string) };
                    return error.EqualEqualIncompatibleTypes;
                },
                .less_than => {
                    if (lhs != .number) return error.LessLhsNonNumber;
                    if (rhs != .number) return error.LessRhsNonNumber;
                    break :a .{ .boolean = lhs.number < rhs.number };
                },
                .less_than_or_equal => {
                    if (lhs != .number) return error.LessEqualLhsNonNumber;
                    if (rhs != .number) return error.LessEqualRhsNonNumber;
                    break :a .{ .boolean = lhs.number <= rhs.number };
                },
                .greater_than => {
                    if (lhs != .number) return error.GreaterLhsNonNumber;
                    if (rhs != .number) return error.GreaterRhsNonNumber;
                    break :a .{ .boolean = lhs.number > rhs.number };
                },
                .greater_than_or_equal => {
                    if (lhs != .number) return error.GreaterEqualLhsNonNumber;
                    if (rhs != .number) return error.GreaterEqualRhsNonNumber;
                    break :a .{ .boolean = lhs.number >= rhs.number };
                },
                .add => {
                    if (lhs != .number) return error.PlusLhsNonNumber;
                    if (rhs != .number) return error.PlusRhsNonNumber;
                    break :a .{ .number = lhs.number + rhs.number };
                },
                .subtract => {
                    if (lhs != .number) return error.MinusLhsNonNumber;
                    if (rhs != .number) return error.MinusRhsNonNumber;
                    break :a .{ .number = lhs.number - rhs.number };
                },
                .multiply => {
                    if (lhs != .number) return error.AsteriskLhsNonNumber;
                    if (rhs != .number) return error.AsteriskRhsNonNumber;
                    break :a .{ .number = lhs.number * rhs.number };
                },
                .divide => {
                    if (lhs != .number) return error.SlashLhsNonNumber;
                    if (rhs != .number) return error.SlashRhsNonNumber;
                    if (rhs.number == 0.0) return error.DivideByZero;
                    break :a .{ .number = lhs.number / rhs.number };
                },
            }
        },
    };
}

test "F" {
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("{any}", .{true});
    std.debug.print("\n", .{});
    std.debug.print("{any}", .{false});
    std.debug.print("\n", .{});
    std.debug.print("\n", .{});
}
