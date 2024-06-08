const std = @import("std");
const Allocator = std.mem.Allocator;
const openapi = @import("openapi.zig");
const sliceEql = @import("util.zig").sliceEql;
const _target = @import("target.zig");
const Target = _target.Target;
const Jsdoc = _target.Jsdoc;
const Typescript = _target.Typescript;

const stdout = std.io.getStdOut().writer();

const OutputResult = struct {
    num_types: usize,
    output_str: []u8,
};

fn buildOutput(allocator: Allocator, target: Target, json_contents: []u8) !OutputResult {
    const json = try std.json.parseFromSlice(std.json.Value, allocator, json_contents, .{});
    defer json.deinit();

    var contents = std.ArrayList([]const u8).init(allocator);
    defer contents.deinit();

    const schemas = json.value.object.get("components").?.object.get("schemas").?.object;
    for (schemas.keys(), schemas.values()) |key, value| {
        try contents.append(try target.buildTypedef(allocator, key, value));
    }

    const num_types = schemas.keys().len;
    const output_str = try std.mem.join(allocator, "\n", contents.items);

    return OutputResult{ .num_types = num_types, .output_str = output_str };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args_with_exe = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_with_exe);

    const args = Args.init(args_with_exe[1..]) catch |err| {
        switch (err) {
            error.HelpRequested => return,
            else => return err,
        }
    };
    const target = args.target;

    const input_file = try std.fs.cwd().openFile(args.input_file, .{ .mode = .read_only });
    defer input_file.close();

    const stat = try input_file.stat();
    const input_contents = try input_file.readToEndAlloc(allocator, stat.size);

    const output_file = try std.fs.cwd().createFile(args.output_file, .{});
    defer output_file.close();

    const output = try buildOutput(allocator, target, input_contents);
    try output_file.writeAll(output.output_str);

    const target_types_name = switch (target) {
        .jsdoc => "JSDoc typedefs",
        .typescript => "TypeScript types",
    };

    try stdout.print(
        "Successfully written {d} {s} to {s}.\n",
        .{ output.num_types, target_types_name, args.output_file },
    );
}

const Args = struct {
    target: Target,
    input_file: []const u8,
    output_file: []const u8,

    pub fn init(args: []const []const u8) !Args {
        var target: ?Target = null;
        var input_file: ?[]const u8 = null;
        var output_file: ?[]const u8 = null;

        for (args) |arg| {
            if (sliceEql(arg, "-h") or sliceEql(arg, "-help")) {
                try Args.help();
                return error.HelpRequested;
            } else if (sliceEql(arg, "-target=jsdoc")) {
                target = Target{ .jsdoc = Jsdoc{} };
            } else if (sliceEql(arg, "-target=ts") or sliceEql(arg, "-target=typescript")) {
                target = Target{ .typescript = Typescript{} };
            } else if (input_file == null) {
                input_file = arg;
            } else if (output_file == null) {
                output_file = arg;
            } else {
                try Args.help();
                return error.InvalidArgument;
            }
        }

        if (target == null or input_file == null or output_file == null) {
            try Args.help();
            return error.InvalidArgument;
        }

        return Args{
            .target = target.?,
            .input_file = input_file.?,
            .output_file = output_file.?,
        };
    }

    pub fn help() !void {
        try stdout.print(
            "Usage: openapi-typegen -target=<jsdoc|ts> <input_file> <output_file>\n",
            .{},
        );
    }
};
