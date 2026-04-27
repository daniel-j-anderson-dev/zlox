const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const EnumSet = std.EnumSet;
const ascii = std.ascii;
const log = std.log;

const zlox = @import("root.zig");
const Token = zlox.Token;
const Lexer = zlox.Lexer;
const Expression = zlox.Expression;

pub const Parser = struct {
    // +---------+
    // | fields  |
    // +---------+

    tokens: []const Token,
    current: usize,

    // +---------+
    // | types   |
    // +---------+

    pub const Self = @This();
    pub const InitError = Allocator.Error || Lexer.Error;
    pub const Error = error{
        MissingRightParenthesis,
        ExpectedExpression,
        UnaryExpressionMissionOperand,
    } || InitError;

    // +---------------------------------+
    // | initializers and deinitializers |
    // +---------------------------------+

    pub fn init(tokens: []const Token) Self {
        return .{
            .tokens = tokens,
            .current = 0,
        };
    }

    pub fn initAlloc(allocator: Allocator, source: []const u8) InitError!Self {
        const tokens = try lex(allocator, source);
        return Self.init(tokens);
    }

    /// Must be called with the same allocator passed to `Parser.initAlloc`.
    /// If `self` was constructed with `Parser.init` the owner of `Parser.tokens` must deallocate
    pub fn deinit(self: *Self, allocator: Allocator) void {
        allocator.free(self.tokens);
        self.tokens = &.{};
        self.current = 0;
    }

    // +---------+
    // | helpers |
    // +---------+

    fn isCurrentInBounds(self: *const Self) bool {
        return self.current < self.tokens.len;
    }

    fn isCurrentOutOfBounds(self: *const Self) bool {
        return self.current >= self.tokens.len;
    }

    fn outOfTokens(self: *const Self) bool {
        return self.isCurrentOutOfBounds() or self.currentToken().kind == .end_of_file;
    }

    fn currentTokenAvailable(self: *const Self) bool {
        return self.isCurrentInBounds() and self.currentToken().kind != .end_of_file;
    }

    fn currentToken(self: *const Self) Token {
        return self.tokens[self.current];
    }

    fn previousToken(self: *const Self) Token {
        return self.tokens[self.current -| 1];
    }

    fn consumeCurrentToken(self: *Self) void {
        if (self.currentTokenAvailable()) {
            self.current +|= 1;
        }
    }

    fn consumeCurrentTokenIf(self: *Self, predicate: fn (Token) bool) bool {
        if (self.currentTokenAvailable() and predicate(self.currentToken())) {
            self.consumeCurrentToken();
            return true;
        } else {
            return false;
        }
    }

    fn kindIs(x: anytype) fn (Token) bool {
        const X = @TypeOf(x);
        switch (X) {
            Token.Kind => return struct {
                pub fn f(token: Token) bool {
                    return x == token.kind;
                }
            }.f,
            EnumSet(Token.Kind) => return struct {
                pub fn f(token: Token) bool {
                    return x.contains(token.kind);
                }
            }.f,
            else => @compileError("parser.Parser.tokenKindIs is only compatible with Token.Kind and EnumSet(Token.Kind)"),
        }
    }

    // +---------------+
    // | grammar rules |
    // +---------------+

    fn expressionRule(self: *Self, allocator: Allocator) Error!*Expression {
        return try self.equalityRule(allocator);
    }

    fn equalityRule(self: *Self, allocator: Allocator) Error!*Expression {
        var expression = try self.comparisonRule(allocator);
        errdefer allocator.free(expression);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.equality_operators))) {
            const temp = try allocator.create(Expression);
            errdefer allocator.free(temp);
            temp.* = .{ .binary = .{
                .left_operand = expression,
                .operator = self.previousToken(),
                .right_operand = try self.comparisonRule(allocator),
            } };
            expression = temp;
        }

        return expression;
    }

    fn comparisonRule(self: *Self, allocator: Allocator) Error!*Expression {
        var expression = try self.comparisonRule(allocator);
        errdefer allocator.free(expression);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.comparison_operators))) {
            const temp = try allocator.create(Expression);
            errdefer allocator.free(temp);
            temp.* = .{ .binary = .{
                .left_operand = expression,
                .operator = self.previousToken(),
                .right_operand = try self.termRule(allocator),
            } };
            expression = temp;
        }

        return expression;
    }

    fn termRule(self: *Self, allocator: Allocator) Error!*Expression {
        var expression = try self.comparisonRule(allocator);
        errdefer allocator.free(expression);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.term_operators))) {
            const temp = try allocator.create(Expression);
            errdefer allocator.free(temp);
            temp.* = .{ .binary = .{
                .left_operand = expression,
                .operator = self.previousToken(),
                .right_operand = try self.factorRule(allocator),
            } };
            expression = temp;
        }

        return expression;
    }

    fn factorRule(self: *Self, allocator: Allocator) Error!*Expression {
        var expression = try self.comparisonRule(allocator);
        errdefer allocator.free(expression);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.factor_operators))) {
            const temp = try allocator.create(Expression);
            errdefer allocator.free(temp);
            temp.* = .{ .binary = .{
                .left_operand = expression,
                .operator = self.previousToken(),
                .right_operand = try self.unaryRule(allocator),
            } };
            expression = temp;
        }

        return expression;
    }

    fn unaryRule(self: *Self, allocator: Allocator) Error!*Expression {
        if (self.consumeCurrentTokenIf(kindIs(Token.Kind.unary_operators))) {
            const temp = try allocator.create(Expression);
            errdefer allocator.free(temp);
            temp.* = .{
                .unary = .{
                    .operator = self.previousToken(),
                    .right_operator = try self.unaryRule(allocator),
                },
            };
        } else {
            try self.primaryRule(allocator);
        }
    }

    fn primaryRule(self: *Self, allocator: Allocator) Error!*Expression {
        if (self.consumeCurrentTokenIf(kindIs(Token.Kind.literal_values))) {
            const temp = try allocator.create(Expression);
            errdefer allocator.free(temp);
            temp.* = .{ .literal = self.previousToken() };
            return temp;
        }

        if (self.consumeCurrentTokenIf(kindIs(.left_parenthesis))) {
            const expression = try self.expressionRule(allocator);
            errdefer allocator.free(expression);
            const right_parenthesis_present = self.consumeCurrentTokenIf(kindIs(.right_parenthesis));
            if (!right_parenthesis_present)
                return Error.MissingRightParenthesis;

            const temp = try allocator.create(Expression);
            errdefer allocator.free(temp);
            temp.* = .{ .grouping = expression };
            return temp;
        }

        return Error.ExpectedExpression;
    }
};

const non_semantic_token_kinds = EnumSet(Token.Kind).initMany(&.{
    .comment,
    .whitespace,
    .unrecognized,
});
const semantic_token_kinds = non_semantic_token_kinds.complement();
fn isSemanticToken(token: Token) bool {
    return semantic_token_kinds.contains(token.kind);
}

/// The caller owns the returned slice; it must be deallocated with the same `Allocator` passed to this function
fn lex(allocator: Allocator, source: []const u8) (Allocator.Error || Lexer.Error)![]const Token {
    var tokens = ArrayList(Token).empty;
    defer tokens.deinit(allocator);

    var lexer = Lexer.init(source);
    while (lexer.next()) |maybe_token| {
        const token = try maybe_token;
        if (!isSemanticToken(token)) continue;
        try tokens.append(allocator, token);
    }

    return try tokens.toOwnedSlice(allocator);
}
