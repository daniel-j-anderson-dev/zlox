const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const activeTag = std.meta.activeTag;
const Tag = std.meta.Tag;
const parseFloat = std.fmt.parseFloat;
const comptimePrint = std.fmt.comptimePrint;
const sliceConcatenate = std.mem.concat;
const sliceEqual = std.mem.eql;

const zlox = @import("root.zig");
const Expression = zlox.Expression;

pub const Value = union(enum) {
    nil,
    boolean: bool,
    number: f64,
    string: String,

    const Self = @This();
    pub const String = struct {
        items: []const u8,
        items_need_to_be_freed: bool,
    };

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .string => |*string| if (string.items_need_to_be_freed) {
                allocator.free(string.items);
                string.items = &.{};
                string.items_need_to_be_freed = false;
            },
            else => {},
        }
    }

    pub fn format(self: *const Self, writer: *Io.Writer) !void {
        try switch (self.*) {
            .nil => writer.print("nil", .{}),
            .boolean => |v| writer.print("{any}", .{v}),
            .number => |v| writer.print("{d}", .{v}),
            .string => |v| writer.print("{s}", .{v.items}),
        };
    }

    pub fn isTruthy(self: *const Self) bool {
        return switch (self.*) {
            .nil => false,
            .boolean => |b| b,
            .number => |n| n != 0.0,
            .string => |string| string.items.len != 0.0,
        };
    }

    pub fn equal(lhs: *const Self, rhs: *const Self) bool {
        const lhs_tag: Tag(Self) = activeTag(lhs.*);
        const rhs_tag: Tag(Self) = activeTag(rhs.*);
        const same_tags = lhs_tag == rhs_tag;
        return if (same_tags)
            switch (lhs_tag) {
            .nil => true,
            .boolean => lhs.boolean == rhs.boolean,
            .number => lhs.number == rhs.number,
            .string => sliceEqual(u8, lhs.string.items, rhs.string.items),
        }
        else false;
    }

    pub fn from(x: anytype) Self {
        const X = @TypeOf(x);
        // const X_info = @typeInfo(X);
        const X_name = @typeName(X);
        return switch (X) {
            Expression.Literal => Self.fromLiteral(x),
            else => @compileError(comptimePrint("invalid argument to zlox.interpreter.Value.from. {s} is not supported", .{X_name})),
        };
    }

    pub fn fromLiteral(literal: Expression.Literal) Self {
        return switch (literal.kind) {
            .nil => .{ .nil = void{} },
            .true => .{ .boolean = true },
            .false => .{ .boolean = false },
            .number => .{ .number = parseFloat(f64, literal.token.lexeme) catch unreachable },
            .string => .{ .string = .{
                .items = trimFirstAndLast(u8, literal.token.lexeme),
                .items_need_to_be_freed = false,
            } },
        };
    }
};

pub const tree_walk = struct {
    // allocator is needed for string concat
    pub fn evaluate(allocator: Allocator, expression: *const Expression) !Value {
        return switch (expression.*) {
            .literal => |literal| Value.fromLiteral(literal),
            .grouping => |inner| try evaluate(allocator, inner),
            .unary => |unary| a: {
                var rhs = try evaluate(allocator, unary.right_operand);
                defer rhs.deinit(allocator);

                break :a switch (unary.operator.kind) {
                    .arithmetic_negate => switch (rhs) {
                        .number => |n| .{ .number = -n },
                        else => return error.UnaryMinusNonNumber,
                    },
                    .boolean_negate => .{ .boolean = !rhs.isTruthy() },
                };
            },
            .binary => |binary| a: {
                var lhs = try evaluate(allocator, binary.left_operand);
                defer lhs.deinit(allocator);

                var rhs = try evaluate(allocator, binary.right_operand);
                defer rhs.deinit(allocator);

                break :a switch (binary.operator.kind) {
                    .not_equal => .{ .boolean = !lhs.equal(&rhs) },
                    .equal => .{ .boolean = lhs.equal(&rhs) },
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
                        if (lhs == .number and rhs == .number)
                            break :a .{ .number = lhs.number + rhs.number };
                        if (lhs == .string and rhs == .string) {
                            break :a .{ .string = .{
                                .items = try sliceConcatenate(allocator, u8, &.{ lhs.string.items, rhs.string.items }),
                                .items_need_to_be_freed = true,
                            } };
                        }
                        return error.AddIncompatibleTypes;
                    },
                    .subtract => {
                        if (lhs != .number) return error.SubtractLhsNonNumber;
                        if (rhs != .number) return error.SubtractRhsNonNumber;
                        break :a .{ .number = lhs.number - rhs.number };
                    },
                    .multiply => {
                        if (lhs != .number) return error.AsteriskLhsNonNumber;
                        if (rhs != .number) return error.AsteriskRhsNonNumber;
                        break :a .{ .number = lhs.number * rhs.number };
                    },
                    .divide => {
                        if (lhs != .number) return error.DivideLhsNonNumber;
                        if (rhs != .number) return error.DivideRhsNonNumber;
                        if (rhs.number == 0.0) return error.DivideByZero;
                        break :a .{ .number = lhs.number / rhs.number };
                    },
                };
            },
        };
    }
};

fn trimFirstAndLast(T: type, slice: []const T) []const T {
    const less_than_two_elements = slice.len < 2;
    const trimmed_slice = if (less_than_two_elements) slice[0..0] else slice[1..slice.len - 1];
    return trimmed_slice;
}

test "union(enum) tags" {
    const x = union(enum) {
        a: u0,
        b: u1,
        c: u2,
        d: u3,
    };

    std.debug.print("\n\n", .{});
    for (std.enums.values(Tag(x))) |v| {
        try std.testing.expect(@TypeOf(v) == Tag(x));
        std.debug.print("{s}\n", .{@typeName(@TypeOf(v))});
        std.debug.print("{s}\n", .{@tagName(v)});
    }
    std.debug.print("\n\n", .{});
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
