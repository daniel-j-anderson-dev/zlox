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
