const std = @import("std");
const Io = std.Io;
const File = std.Io.File;
const Dir = std.Io.Dir;
const log = std.log;
const Allocator = std.mem.Allocator;
const ascii = std.ascii;

const zlox = @import("root.zig");
const lexEagerAlloc = zlox.lexEagerAlloc;
const Parser = zlox.Parser;
const Expression = zlox.Expression;
const tree_walk = zlox.tree_walk;

const buffer_size = 1024;

fn run(allocator: Allocator, io: Io, source_code: []const u8) !void {
    // initialize stdout writer
    log.debug("initializing stdout", .{});
    const stdout_file = File.stdout();
    var stdout_buffer: [buffer_size]u8 = undefined;
    var stdout_writer = stdout_file.writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    log.debug("lexing source code into tokens", .{});
    const tokens = lexEagerAlloc(allocator, source_code) catch |lex_eager_error| {
        if (lex_eager_error == error.UnterminatedStringLiteral) {
            log.err("failed to lex source: {any}", .{lex_eager_error});
            return;
        }
        return lex_eager_error;
    };
    defer allocator.free(tokens);

    log.debug("initializing parser", .{});
    var parser = Parser.init(tokens);

    log.debug("evaluating expressions from parser", .{});
    while (true) {
        const expression = parser.parse(allocator) catch |parse_error| {
            const out_of_tokens = parser.outOfTokens();
            log.debug("parser is {s}out of tokens", .{if (out_of_tokens) "" else "not "});
            log.debug("failed to parse source: {s}", .{@errorName(parse_error)});
            if (parser.error_token) |error_token| {
                if (out_of_tokens) return;
                log.err("error token: {f}", .{error_token});
            }

            if (out_of_tokens) break else continue;
        };
        defer expression.deinit(allocator);

        const polish_notation = try expression.toPolishNotationAlloc(allocator);
        defer allocator.free(polish_notation);
        log.debug("polish notation: {s}", .{polish_notation});

        const reduced_value = tree_walk.evaluate(expression) catch |evaluation_error| {
            log.err("failed to evaluate: {s}", .{@errorName(evaluation_error)});
            continue;
        };
        try stdout.print("{f}\n", .{reduced_value});
        try stdout.flush();
    }
}

pub fn runFile(allocator: Allocator, io: Io, path: [:0]const u8) !void {
    log.debug("Reading contents of {s}", .{path});
    const file_contents = try Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .unlimited,
    );
    defer allocator.free(file_contents);
    log.info("Running file contents", .{});
    try run(allocator, io, file_contents);
}

pub fn runPrompt(allocator: Allocator, io: Io) !void {
    // initialize stdout writer
    log.debug("initializing stdout", .{});
    const stdout_file = File.stdout();
    var stdout_buffer: [buffer_size]u8 = undefined;
    var stdout_writer = stdout_file.writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    // initialize stdin reader
    log.debug("initializing stdin", .{});
    const stdin_file = File.stdin();
    var stdin_buffer: [buffer_size]u8 = undefined;
    var stdin_reader = stdin_file.reader(io, &stdin_buffer);
    var stdin = &stdin_reader.interface;

    while (true) {
        try stdout.print("> ", .{});
        try stdout.flush();

        const raw_line = try stdin.takeDelimiter('\n') orelse break;
        const line = std.mem.trim(u8, raw_line, &ascii.whitespace);
        if (line.len == 0) continue;
        if (equalIgnoreAsciiCase(line, "exit")) break;

        try run(allocator, io, line);
    }
}

pub fn equalIgnoreAsciiCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ai, bi|
        if (ascii.toLower(ai) != ascii.toLower(bi)) return false;
    return true;
}
