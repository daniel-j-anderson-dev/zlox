const std = @import("std");
const Allocator = std.mem.Allocator;
const EnumSet = std.EnumSet;

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
    error_token: ?*const Token,

    // +---------+
    // | types   |
    // +---------+

    pub const Self = @This();
    pub const Error = error{
        MissingRightParenthesis,
        ExpectedExpression,
        NotImplemented,
    } || Allocator.Error;

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

    fn consumeTokenIf(self: *Self, predicate: fn (Token) bool) bool {
        if (self.currentTokenAvailable() and predicate(self.currentToken())) {
            self.consumeCurrentToken();
            return true;
        } else {
            return false;
        }
    }

    fn synchronize(self: *Self) void {
        const statement_boundary = comptime EnumSet(Token.Kind).initMany(&.{ .class, .fun, .@"var", .@"for", .@"if", .@"while", .print, .@"return" });

        self.consumeCurrentToken();
        while (self.currentTokenAvailable()) {
            const previous = self.previousToken();
            const current = self.currentToken();
            const is_statement_boundary = previous.kind == .semicolon or statement_boundary.contains(current.kind);
            if (is_statement_boundary) return;
            self.consumeCurrentToken();
        }
    }

    // +------------------+
    // | the whole point! |
    // +------------------+

    pub fn parse(self: *Self, allocator: Allocator) Error!*Expression {
        return self.expressionRule(allocator);
    }

    // +---------------+
    // | grammar rules |
    // +---------------+

    fn expressionRule(self: *Self, allocator: Allocator) Error!*Expression {
        return try self.equalityRule(allocator);
    }

    fn equalityRule(self: *Self, allocator: Allocator) Error!*Expression {
        var left_operand = try self.comparisonRule(allocator);
        errdefer left_operand.deinit(allocator);

        while (self.consumeTokenIf(is(Token.Kind.equality_operators))) {
            const consumed_token = self.previousToken();
            const operator = Expression.Binary.Operator{
                .token = consumed_token,
                .kind = switch (consumed_token.kind) {
                    .bang_equal => .not_equal,
                    .equal_equal => .equal,
                    else => unreachable, // unreachable because of while predicate
                },
            };
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

        while (self.consumeTokenIf(is(Token.Kind.comparison_operators))) {
            const consumed_token = self.previousToken();
            const operator = Expression.Binary.Operator{
                .token = consumed_token,
                .kind = switch (consumed_token.kind) {
                    .less => .less_than,
                    .less_equal => .less_than_or_equal,
                    .greater => .greater_than,
                    .greater_equal => .greater_than_or_equal,
                    else => unreachable, // unreachable because of while predicate
                },
            };
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

        while (self.consumeTokenIf(is(Token.Kind.term_operators))) {
            const consumed_token = self.previousToken();
            const operator = Expression.Binary.Operator{
                .token = consumed_token,
                .kind = switch (consumed_token.kind) {
                    .plus => .add,
                    .minus => .subtract,
                    else => unreachable, // unreachable because of while predicate
                },
            };
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

        while (self.consumeTokenIf(is(Token.Kind.factor_operators))) {
            const consumed_token = self.previousToken();
            const operator = Expression.Binary.Operator{
                .token = consumed_token,
                .kind = switch (consumed_token.kind) {
                    .asterisk => .multiply,
                    .slash => .divide,
                    else => unreachable, // unreachable because of while predicate
                },
            };
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
        if (self.consumeTokenIf(is(Token.Kind.unary_operators))) {
            const consumed_token = self.previousToken();
            const operator = Expression.Unary.Operator{
                .token = consumed_token,
                .kind = switch (consumed_token.kind) {
                    .bang => .boolean_negate,
                    .minus => .arithmetic_negate,
                    else => unreachable, // unreachable because of while predicate
                },
            };
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
        if (self.consumeTokenIf(is(Token.Kind.literal_values))) {
            const consumed_token = self.previousToken();
            const kind: Expression.Literal.Kind = switch (consumed_token.kind) {
                .nil => .nil,
                .true => .true,
                .false => .false,
                .number => .number,
                .string => .string,
                else => unreachable, // because of if predicate
            };

            const temp = try allocator.create(Expression);
            temp.* = .{ .literal = .{
                .token = consumed_token,
                .kind = kind,
            } };
            return temp;
        }

        if (self.consumeTokenIf(is(.left_parenthesis))) {
            const grouping = try self.expressionRule(allocator);
            errdefer grouping.deinit(allocator);

            const right_parenthesis_present = self.consumeTokenIf(is(.right_parenthesis));
            if (!right_parenthesis_present) {
                self.error_token = &self.tokens[self.current];
                return Error.MissingRightParenthesis;
            }

            const temp = try allocator.create(Expression);
            temp.* = .{ .grouping = grouping };
            return temp;
        }

        if (self.consumeTokenIf(is(Token.Kind.keywords))) {
            self.error_token = &self.tokens[self.current - 1];
            return Error.NotImplemented;
        }

        if (self.consumeTokenIf(is(.identifier))) {
            self.error_token = &self.tokens[self.current - 1];
            return Error.NotImplemented;
        }

        self.error_token = &self.tokens[self.current];
        return Error.ExpectedExpression;
    }
};

fn is(x: anytype) fn (Token) bool {
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
