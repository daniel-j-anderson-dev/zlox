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
    const lexer = Lexer.new(source_code);
    _ = lexer;
    _ = io;
    //TODO
}

pub fn runFile(io: Io, allocator: Allocator, path: [:0]const u8) !void {
    const file_contents = try Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
    defer allocator.free(file_contents);
    try run(io, file_contents);
}

pub fn runPrompt(io: Io) !void {
    // initialize stdout writer
    const stdout_file = File.stdout();
    var stdout_buffer: [buffer_size]u8 = undefined;
    var stdout_writer = stdout_file.writer(io, &stdout_buffer);
    var stdout = &stdout_writer.interface;

    // initialize stdin reader
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

        try run(io, line);
    }
}

pub fn equalIgnoreAsciiCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ai, bi|
        if (ascii.toLower(ai) != ascii.toLower(bi)) return false;
    return true;
}
