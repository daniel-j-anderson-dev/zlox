const std = @import("std");
const ascii = std.ascii;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const log = std.log;
const stringToEnum = std.meta.stringToEnum;

const zlox = @import("root.zig");
const Token = zlox.Token;

/// The caller owns the returned slice; it must be deallocated with the same `Allocator` passed to this function
pub fn lexEagerAlloc(allocator: Allocator, source: []const u8) (Allocator.Error || Lexer.Error)![]const Token {
    var tokens = ArrayList(Token).empty;
    defer tokens.deinit(allocator);

    var lexer = Lexer.init(source);
    while (lexer.next()) |maybe_token| {
        const token = try maybe_token;
        const is_non_semantic_token = Token.Kind.non_semantic.contains(token.kind);
        log.debug("{f}", .{token});
        if (is_non_semantic_token) {
            // log.debug("non-semantic token skipped", .{});
            continue;
        }
        try tokens.append(allocator, token);
    }

    return try tokens.toOwnedSlice(allocator);
}

pub const Lexer = struct {
    source: []const u8,
    lexeme_start: usize,
    lexeme_end: usize,
    line_number: usize,
    end_of_file_emitted: bool,

    const Self = @This();
    pub const Error = error{
        UnterminatedStringLiteral,
    };

    pub fn init(source: []const u8) Self {
        return .{
            .source = source,
            .lexeme_start = 0,
            .lexeme_end = 0,
            .line_number = 1,
            .end_of_file_emitted = false,
        };
    }

    pub fn next(self: *Self) ?Error!Token {
        if (self.outOfSourceBytes())
            return self.endOfFile() orelse return null;

        self.startNewLexeme();
        const current = self.currentByte();
        self.extendLexeme();

        const line_number = self.line_number;
        const kind: Token.Kind = switch (current) {
            '(' => .left_parenthesis,
            ')' => .right_parenthesis,
            '{' => .left_curly_brace,
            '}' => .right_curly_brace,
            ',' => .comma,
            '.' => .dot,
            '-' => .minus,
            '+' => .plus,
            ';' => .semicolon,
            '*' => .asterisk,
            '!' => if (self.extendLexemeIf(is('='))) .bang_equal else .bang,
            '=' => if (self.extendLexemeIf(is('='))) .equal_equal else .equal,
            '<' => if (self.extendLexemeIf(is('='))) .less_equal else .less,
            '>' => if (self.extendLexemeIf(is('='))) .greater_equal else .greater,
            '/' => if (self.extendLexemeIf(is('/'))) self.comment() else .slash,
            '"' => try self.stringLiteral(),
            '0'...'9' => self.numberLiteral(),
            'A'...'Z', 'a'...'z', '_' => self.identifier(),
            ' ', '\t', '\n', '\r', ascii.control_code.vt, ascii.control_code.ff => self.whitespace(),
            else => self.unrecognized(),
        };
        const lexeme_ = self.lexeme();

        return Token {
            .kind = kind,
            .lexeme = lexeme_,
            .line_number = line_number
        };
    }

    fn sourceBytesAvailable(self: *const Self) bool {
        return self.lexeme_end < self.source.len;
    }

    fn outOfSourceBytes(self: *const Self) bool {
        return self.lexeme_end >= self.source.len;
    }

    fn currentByte(self: *const Self) u8 {
        return self.source[self.lexeme_end];
    }

    fn lexeme(self: *const Self) []const u8 {
        return self.source[self.lexeme_start..self.lexeme_end];
    }

    fn startNewLexeme(self: *Self) void {
        self.lexeme_start = self.lexeme_end;
    }

    fn extendLexeme(self: *Self) void {
        self.lexeme_end +|= 1;
    }

    fn nextLine(self: *Self) void {
        self.line_number +|= 1;
    }

    fn accountForNewLinesInLexeme(self: *Self) void {
        const new_line_count = std.mem.count(u8, self.lexeme(), "\n");
        self.line_number +|= new_line_count;
    }

    fn extendLexemeIf(self: *Self, predicate: fn (u8) bool) bool {
        if (self.sourceBytesAvailable() and predicate(self.currentByte())) {
            self.extendLexeme();
            return true;
        } else {
            return false;
        }
    }

    fn extendLexemeWhile(self: *Self, predicate: fn (u8) bool) void {
        while (self.extendLexemeIf(predicate)) {}
    }

    fn endOfFile(self: *Self) ?Token {
        if (self.end_of_file_emitted) {
            return null;
        } else {
            self.end_of_file_emitted = true;
            return .{
                .kind = .end_of_file,
                .lexeme = "",
                .line_number = self.line_number,
            };
        }
    }

    fn stringLiteral(self: *Self) Error!Token.Kind {
        self.extendLexemeWhile(not(is('"')));
        const is_closing_quote_present = self.extendLexemeIf(is('"'));
        if (!is_closing_quote_present)
            return Error.UnterminatedStringLiteral;
        self.accountForNewLinesInLexeme();
        return .string;
    }

    fn numberLiteral(self: *Self) Token.Kind {
        self.extendLexemeWhile(ascii.isDigit);
        const is_decimal_present = self.extendLexemeIf(is('.'));
        if (is_decimal_present)
            self.extendLexemeWhile(ascii.isDigit);
        return .number;
    }

    fn extendedLexemeToKeyword(self: *Self) ?Token.Kind {
        self.extendLexemeWhile(ascii.isAlphabetic);
        const lexeme_kind = stringToEnum(Token.Kind, self.lexeme()) orelse return null;
        const is_keyword = Token.Kind.keywords.contains(lexeme_kind);
        return if (is_keyword) lexeme_kind else null;
    }

    fn identifier(self: *Self) Token.Kind {
        if (self.extendedLexemeToKeyword()) |keyword_kind| {
            return keyword_kind;
        }
        self.extendLexemeWhile(Or(ascii.isAlphanumeric, is('_')));
        return .identifier;
    }

    fn whitespace(self: *Self) Token.Kind {
        self.extendLexemeWhile(is(&ascii.whitespace));
        self.accountForNewLinesInLexeme();
        return .whitespace;
    }

    fn comment(self: *Self) Token.Kind {
        self.extendLexemeWhile(not(is('\n')));
        return .comment;
    }

    fn unrecognized(self: *Self) Token.Kind {
        self.extendLexemeWhile(not(is(recognized)));
        return .unrecognized;
    }
};

fn is(x: anytype) fn(u8) bool {
    const X = @TypeOf(x);
    return switch (X) {
        u8 => struct {
            pub fn f(b: u8) bool {
                return x == b;
            }
        }.f,
        []const u8 => struct {
            pub fn f(needle: u8) bool {
                return std.mem.findScalar(u8, x, needle) != null;
            }
        }.f,
        else => @compileError("lexer.is only supports u8, and []const u8"),
    };
}

fn not(predicate: fn (u8) bool) fn (u8) bool {
    return struct {
        pub fn f(a: u8) bool {
            return !predicate(a);
        }
    }.f;
}

fn Or(predicate_a: fn (u8) bool, predicate_b: fn (u8) bool) fn (u8) bool {
    return struct {
        pub fn f(a: u8) bool {
            return predicate_a(a) or predicate_b(a);
        }
    }.f;
}

const recognized = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz<>./-=!(){}*;\"" ++ &ascii.whitespace;
