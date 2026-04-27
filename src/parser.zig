const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const EnumSet = std.EnumSet;
const ascii = std.ascii;

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

    fn tokensAvailable(self: *const Self) bool {
        return self.isCurrentInBounds() and self.currentToken().kind != .end_of_file;
    }

    fn currentToken(self: *const Self) Token {
        return self.tokens[self.current];
    }

    fn previousToken(self: *const Self) Token {
        return self.tokens[self.current -| 1];
    }

    fn consumeCurrentToken(self: *Self) void {
        if (self.tokensAvailable()) {
            self.current +|= 1;
        }
    }

    fn consumeCurrentTokenOfKind(self: *Self, kinds: EnumSet(Token.Kind)) bool {
        const should_consume = self.tokensAvailable() and kinds.contains(self.currentToken().kind);
        if (should_consume) self.consumeCurrentToken();
        return should_consume;
    }

    // +---------------+
    // | grammar rules |
    // +---------------+
};

const non_semantic_token_kinds = EnumSet(Token.Kind)
    .initMany(&.{
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

    var lexer = Lexer.init(source).filter(&isSemanticToken);
    while (try lexer.next()) |token|
        try tokens.append(allocator, token);

    return try tokens.toOwnedSlice(allocator);
}
