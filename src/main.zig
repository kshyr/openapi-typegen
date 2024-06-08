const std = @import("std");
const openapi = @import("openapi.zig");
const sliceEql = @import("util.zig").sliceEql;
const _target = @import("target.zig");
const Target = _target.Target;
const Jsdoc = _target.Jsdoc;
const Typescript = _target.Typescript;

const stdout = std.io.getStdOut().writer();

var typescript = true;

fn buildOutput(allocator: std.mem.Allocator, target: Target, json_contents: []u8) ![]u8 {
    const json = try std.json.parseFromSlice(std.json.Value, allocator, json_contents, .{});
    defer json.deinit();

    var contents = std.ArrayList([]const u8).init(allocator);
    defer contents.deinit();

    try stdout.print("Parsed JSON: {any}\n", .{json});

    const schemas = json.value.object.get("components").?.object.get("schemas").?.object;
    for (schemas.keys(), schemas.values()) |key, value| {
        try contents.append(try target.buildTypedef(allocator, key, value));
    }

    return std.mem.join(allocator, "\n", contents.items);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args_with_exe = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_with_exe);
    const args = args_with_exe[1..]; // remove the executable name

    if (args.len != 2 or sliceEql(args[0], "help")) {
        try stdout.print("Usage: openapi-to-jsdoc <input_file> <output_file>\n", .{});
    }

    const input_file = try std.fs.cwd().openFile(args[0], .{ .mode = .read_only });
    defer input_file.close();

    const stat = try input_file.stat();
    const input_contents = try input_file.readToEndAlloc(allocator, stat.size);

    const output_file = try std.fs.cwd().createFile(args[1], .{});
    defer output_file.close();

    var target = Target{ .jsdoc = Jsdoc{} };
    if (typescript) {
        target = Target{ .typescript = Typescript{} };
    }

    const output_str = try buildOutput(allocator, target, input_contents);

    try output_file.writeAll(output_str);

    try stdout.print("Successfully written JSDoc typedefs to {s}.\n", .{args[1]});
}
