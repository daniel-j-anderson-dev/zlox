const std = @import("std");
const Io = std.Io;
const File = std.Io.File;
const Dir = std.Io.Dir;
const log = std.log;
const Allocator = std.mem.Allocator;
const ascii = std.ascii;

const zlox = @import("root.zig");
const Lexer = zlox.Lexer;
const Parser = zlox.Parser;
const Expression = zlox.Expression;

const buffer_size = 1024;

fn run(io: Io, allocator: Allocator, source_code: []const u8) !void {
    // initialize stdout writer
    log.debug("initializing stdout", .{});
    const stdout_file = File.stdout();
    var stdout_buffer: [buffer_size]u8 = undefined;
    var stdout_writer = stdout_file.writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    log.debug("initializing Parser", .{});
    var parser = Parser.initAlloc(allocator, source_code) catch |init_error| {
        if (init_error == error.UnterminatedStringLiteral) {
            log.err("failed to lex source: {any}", .{init_error});
            return;
        }
        return init_error;
    };
    defer parser.deinit(allocator);

    log.debug("printing expressions from parser", .{});
    while (true) {
        log.debug("attempt to parse expression", .{});
        const e = parser.expressionRule(allocator) catch |parse_error| {
            if (parser.outOfTokens()) {
                log.debug("parser is out of tokens", .{});
            } else {
                log.err("failed to parse source: {any}", .{parse_error});
            }
            break;
        };
        defer e.deinit(allocator);

        const s = try e.toPolishNotationAlloc(allocator);
        defer allocator.free(s);

        try stdout.print("{s}\n", .{s});
        try stdout.flush();
    }
}

pub fn runFile(io: Io, allocator: Allocator, path: [:0]const u8) !void {
    log.debug("Reading contents of {s}", .{path});
    const file_contents = try Dir.cwd().readFileAlloc(
        io,
        path,
        allocator,
        .unlimited,
    );
    defer allocator.free(file_contents);
    log.info("Running file contents", .{});
    try run(io, allocator, file_contents);
}

pub fn runPrompt(io: Io, allocator: Allocator) !void {
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

        try run(io, allocator, line);
    }
}

pub fn equalIgnoreAsciiCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ai, bi|
        if (ascii.toLower(ai) != ascii.toLower(bi)) return false;
    return true;
}
