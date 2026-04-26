const std = @import("std");
const Io = std.Io;
const File = std.Io.File;
const Dir = std.Io.Dir;
const Allocator = std.mem.Allocator;

const zlox = @import("root.zig");
const Lexer = zlox.Lexer;

fn run(io: *Io, source_code: []const u8) !void {
    // TODO: implement
    _ = io;
    _ = source_code;
}

/// Caller owns the returned slice; deallocate it with the same allocator passed as an argument.
fn readFileBytes(io: *Io, allocator: Allocator, path: [:0]const u8) ![]const u8 {
    // TODO: implement
    _ = io;
    _ = allocator;
    _ = path;
}

pub fn runFile(io: *Io, allocator: Allocator, path: [:0]const u8) !void {
    // TODO: implement
    _ = io;
    _ = allocator;
    _ = path;
}

pub fn runPrompt(io: *Io) !void {
    // TODO: implement
    _ = io;
}
