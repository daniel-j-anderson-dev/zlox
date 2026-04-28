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

    log.debug("printing expressions from parser", .{});
    while (true) {
        log.debug("attempt to parse expression", .{});
        const expression = parser.expressionRule(allocator) catch |parse_error| {
            if (parser.outOfTokens()) {
                log.debug("parser is out of tokens", .{});
            } else {
                log.err("failed to parse source: {any}", .{parse_error});
            }
            break;
        };
        defer {
            expression.deinit(allocator);
        }

        const s = try expression.toPolishNotationAlloc(allocator);
        defer allocator.free(s);

        try stdout.print("{s}\n", .{s});
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
