const std = @import("std");
const Allocator = std.mem.Allocator;

pub const zlox = @import("../root.zig");
pub const ast = zlox.abstract_syntax_tree;

pub const Statement = union(enum) {
    expression: Expression,
    print: Print,

    const Self = @This();

    pub const Expression = struct {
        expression: *ast.Expression,
    };

    pub const Print = struct {
        expression: *ast.Expression,
    };

    pub fn deinit(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .expression => |expression_statement| {
                expression_statement.expression.deinit(allocator);
            },
            .print => |print_statement| {
                print_statement.expression.deinit(allocator);
            },
        }
        allocator.destroy(self);
    }
};
