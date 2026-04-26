const std = @import("std");
const Io = std.Io;
const File = std.Io.File;
const Dir = std.Io.Dir;
const log = std.log;
const Allocator = std.mem.Allocator;
const ascii = std.ascii;

const zlox = @import("root.zig");
const Lexer = zlox.Lexer;

const buffer_size = 1024;

fn run(io: Io, source_code: []const u8) !void {
    // initialize stdout writer
    log.debug("initializing stdout", .{});
    const stdout_file = File.stdout();
    var stdout_buffer: [buffer_size]u8 = undefined;
    var stdout_writer = stdout_file.writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    log.debug("initializing Lexer", .{});
    var lexer = Lexer.init(source_code);

    log.debug("printing all tokens in Lexer", .{});
    while (true) {
        const token = lexer.next() catch |lexical_error| {
            log.debug("lexical error: {any}", .{lexical_error});
            continue;
        } orelse {
            log.debug("lexer is out of tokens", .{});
            break;
        };
        log.debug("line number: {d}", .{lexer.line_number});
        try stdout.print("{f}\n", .{token});
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
    try run(io, file_contents);
}

pub fn runPrompt(io: Io) !void {
    // initialize stdout writer
    log.debug("Initializing stdout", .{});
    const stdout_file = File.stdout();
    var stdout_buffer: [buffer_size]u8 = undefined;
    var stdout_writer = stdout_file.writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    // initialize stdin reader
    log.debug("lexer is out of tokens", .{});
    const stdin_file = File.stdin();
    var stdin_buffer: [buffer_size]u8 = undefined;
    var stdin_reader = stdin_file.reader(io, &stdin_buffer);
    var stdin = &stdin_reader.interface;

    log.info("staring REPL", .{});
    while (true) {
        try stdout.print("> ", .{});
        try stdout.flush();

        const raw_line = try stdin.takeDelimiter('\n') orelse break;
        const line = std.mem.trim(u8, raw_line, &ascii.whitespace);
        if (line.len == 0) continue;
        if (equalIgnoreAsciiCase(line, "exit")) {
            log.info("Exiting REPL", .{});
            break;
        }

        try run(io, line);
    }
}

pub fn equalIgnoreAsciiCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ai, bi|
        if (ascii.toLower(ai) != ascii.toLower(bi)) return false;
    return true;
}
