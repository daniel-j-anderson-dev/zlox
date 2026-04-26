const std = @import("std");
const Io = std.Io;
const File = std.Io.File;
const Dir = std.Io.Dir;
const Allocator = std.mem.Allocator;

const zlox = @import("root.zig");
const Lexer = zlox.Lexer;

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
    // TODO
    _ = io;
}
