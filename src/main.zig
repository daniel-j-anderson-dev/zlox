const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const log = std.log;

const zlox = @import("zlox");
const equalIgnoreAsciiCase = zlox.equalIgnoreAsciiCase;

const usage_message =
    "Usage:\n" ++
    "Run REPL: zlox\n" ++
    "Run a lox source file: zlox path/to/lox/source.lox";

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const command_line_arguments = try init.minimal.args.toSlice(arena);

    const input_output = init.io;

    const general_purpose_allocator = init.gpa;

    switch (command_line_arguments.len) {
        0, 1 => {
            log.info("Starting lox REPL", .{});
            try zlox.runPrompt(input_output);
        },
        2 => {
            if (equalIgnoreAsciiCase(command_line_arguments[1], "usage")) {
                log.info("{s}", .{usage_message});
                return;
            }

            const source_file_path = command_line_arguments[1];
            log.info("Running file: {s}", .{source_file_path});
            try zlox.runFile(
                input_output,
                general_purpose_allocator,
                command_line_arguments[1],
            );
        },
        else => {
            log.err("{s}", .{usage_message});
            return error.TooManyArgs;
        },
    }
}
