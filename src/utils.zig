const std = @import("std");
const Io = std.Io;
const File = std.Io.File;
const Dir = std.Io.Dir;
const Allocator = std.mem.Allocator;

const zlox = @import("root.zig");
const Lexer = zlox.Lexer;

const buffer_size = 1024;

fn run(io: *Io, source_code: []const u8) !void {
    const lexer = Lexer.new(source_code);
    _ = lexer;
    _ = io;
    //TODO
}

pub fn runFile(io: *Io, allocator: Allocator, path: [:0]const u8) !void {
    const file_contents = try Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
    defer allocator.free(file_contents);
    try run(io, file_contents);
}

pub fn runPrompt(io: *Io) !void {
    // initialize stdout writer
    const stdout_file = File.stdout();
    var stdout_buffer = [_]u8{0} ** buffer_size;
    const stdout_writer = stdout_file.writer(io, &stdout_buffer);
    var stdout = stdout_writer.interface;

    // initialize stdout reader
    const stdin_file = File.stdin();
    var stdin_buffer = [_]u8{0} ** buffer_size;
    const stdin_reader = stdin_file.reader(io, &stdin_buffer);
    var stdin = stdin_reader.interface;

    while (true) {
        try stdout.print("> ", .{});
        try stdout.flush();

        const line = try stdin.takeDelimiter('\n') orelse break;

        if (line.len == 0) continue;

        try run(io, line);
    }
}
