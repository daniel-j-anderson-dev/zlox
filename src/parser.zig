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
            .error_token = null,
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

    pub fn outOfTokens(self: *const Self) bool {
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
            Token.Kind, @EnumLiteral() => return struct {
                pub fn f(token: Token) bool {
                    return @as(Token.Kind, x) == token.kind;
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

    pub fn expressionRule(self: *Self, allocator: Allocator) Error!*Expression {
        return try self.equalityRule(allocator);
    }

    fn equalityRule(self: *Self, allocator: Allocator) Error!*Expression {
        var left_operand = try self.comparisonRule(allocator);
        errdefer left_operand.deinit(allocator);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.equality_operators))) {
            const operator = self.previousToken();
            const right_operand = try self.comparisonRule(allocator);
            errdefer right_operand.deinit(allocator);

            const temp = try allocator.create(Expression);
            temp.* = .{ .binary = .{
                .left_operand = left_operand,
                .operator = operator,
                .right_operand = right_operand,
            } };
            left_operand = temp;
        }

        return left_operand;
    }

    fn comparisonRule(self: *Self, allocator: Allocator) Error!*Expression {
        var left_operand = try self.termRule(allocator);
        errdefer left_operand.deinit(allocator);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.comparison_operators))) {
            const operator = self.previousToken();
            const right_operand = try self.termRule(allocator);
            errdefer right_operand.deinit(allocator);

            const temp = try allocator.create(Expression);
            temp.* = .{ .binary = .{
                .left_operand = left_operand,
                .operator = operator,
                .right_operand = right_operand,
            } };
            left_operand = temp;
        }

        return left_operand;
    }

    fn termRule(self: *Self, allocator: Allocator) Error!*Expression {
        var left_operand = try self.factorRule(allocator);
        errdefer left_operand.deinit(allocator);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.term_operators))) {
            const operator = self.previousToken();
            const right_operand = try self.factorRule(allocator);
            errdefer right_operand.deinit(allocator);

            const temp = try allocator.create(Expression);
            temp.* = .{ .binary = .{
                .left_operand = left_operand,
                .operator = operator,
                .right_operand = right_operand,
            } };
            left_operand = temp;
        }

        return left_operand;
    }

    fn factorRule(self: *Self, allocator: Allocator) Error!*Expression {
        var left_operand = try self.unaryRule(allocator);
        errdefer left_operand.deinit(allocator);

        while (self.consumeCurrentTokenIf(kindIs(Token.Kind.factor_operators))) {
            const operator = self.previousToken();
            const right_operand = try self.unaryRule(allocator);
            errdefer right_operand.deinit(allocator);

            const temp = try allocator.create(Expression);
            temp.* = .{ .binary = .{
                .left_operand = left_operand,
                .operator = operator,
                .right_operand = right_operand,
            } };
            left_operand = temp;
        }

        return left_operand;
    }

    fn unaryRule(self: *Self, allocator: Allocator) Error!*Expression {
        if (self.consumeCurrentTokenIf(kindIs(Token.Kind.unary_operators))) {
            const operator = self.previousToken();
            const right_operand = try self.unaryRule(allocator);
            errdefer right_operand.deinit(allocator);

            const temp = try allocator.create(Expression);
            temp.* = .{ .unary = .{
                .operator = operator,
                .right_operand = right_operand,
            } };
            return temp;
        } else {
            return try self.primaryRule(allocator);
        }
    }

    fn primaryRule(self: *Self, allocator: Allocator) Error!*Expression {
        if (self.consumeCurrentTokenIf(kindIs(Token.Kind.literal_values))) {
            const literal = self.previousToken();

            const temp = try allocator.create(Expression);
            temp.* = .{ .literal = literal };
            return temp;
        }

        if (self.consumeCurrentTokenIf(kindIs(.left_parenthesis))) {
            const grouping = try self.expressionRule(allocator);
            errdefer grouping.deinit(allocator);

            const right_parenthesis_present = self.consumeCurrentTokenIf(kindIs(.right_parenthesis));
            if (!right_parenthesis_present)
                return Error.MissingRightParenthesis;

            const temp = try allocator.create(Expression);
            temp.* = .{ .grouping = grouping };
            return temp;
        }

        return Error.ExpectedExpression;
    }
};

/// The caller owns the returned slice; it must be deallocated with the same `Allocator` passed to this function
fn lex(allocator: Allocator, source: []const u8) (Allocator.Error || Lexer.Error)![]const Token {
    var tokens = ArrayList(Token).empty;
    defer tokens.deinit(allocator);

    var lexer = Lexer.init(source);
    while (lexer.next()) |maybe_token| {
        const token = try maybe_token;
        if (Token.Kind.non_semantic.contains(token.kind)) continue;
        try tokens.append(allocator, token);
    }

    return try tokens.toOwnedSlice(allocator);
}
