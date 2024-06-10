const std = @import("std");
const Allocator = std.mem.Allocator;

const OpenApi = @import("openapi.zig").OpenApi;
const sliceEql = @import("util.zig").sliceEql;
const _target = @import("target.zig");
const Target = _target.Target;
const Jsdoc = _target.Jsdoc;
const Typescript = _target.Typescript;
const Args = @import("Args.zig");

const stdout = std.io.getStdOut().writer();

const Output = struct {
    num_types: usize,
    str: []u8,
};

const Generator = @This();
allocator: std.mem.Allocator,
args: Args,
output: ?Output,

pub fn init(allocator: Allocator, args_in: []const []const u8) !Generator {
    // Skip the first argument, which is the program name.
    const args = args_in[1..];
    const args_struct = try Args.init(args);

    return Generator{
        .allocator = allocator,
        .args = args_struct,
        .output = null,
    };
}

pub fn run(self: *Generator, input_file: std.fs.File) !Output {
    const stat = try input_file.stat();
    const json_contents = try input_file.readToEndAlloc(self.allocator, stat.size);

    const json = try std.json.parseFromSlice(std.json.Value, self.allocator, json_contents, .{});
    defer json.deinit();
    const openapi = OpenApi.init(json.value);

    var output_slices = std.ArrayList([]const u8).init(self.allocator);
    defer output_slices.deinit();

    const target = self.args.target;
    const schemas = openapi.schemas;
    for (schemas.keys(), schemas.values()) |key, value| {
        try output_slices.append(try target.buildTypedef(self.allocator, key, value));
    }

    const num_types = schemas.keys().len;
    const output_str = try std.mem.join(self.allocator, "\n", output_slices.items);

    return Output{ .num_types = num_types, .str = output_str };
}
