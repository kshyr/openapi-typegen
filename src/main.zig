const std = @import("std");
const Allocator = std.mem.Allocator;

const openapi = @import("openapi.zig");
const sliceEql = @import("util.zig").sliceEql;
const Cli = @import("Cli.zig");
const _target = @import("target.zig");
const Target = _target.Target;
const Jsdoc = _target.Jsdoc;
const Typescript = _target.Typescript;

const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var cli = try Cli.init(allocator, args);

    const input_file = try std.fs.cwd().openFile(cli.args.input_file_path, .{ .mode = .read_only });
    defer input_file.close();

    const output_file = try std.fs.cwd().createFile(cli.args.output_file_path, .{});
    defer output_file.close();

    const output = try cli.generate(input_file);
    try output_file.writeAll(output.str);

    const target = cli.args.target;
    const target_types_name = switch (target) {
        .jsdoc => "JSDoc typedefs",
        .typescript => "TypeScript types",
    };

    try stdout.print(
        "Successfully written {d} {s} to {s}.\n",
        .{ output.num_types, target_types_name, cli.args.output_file_path },
    );
}
