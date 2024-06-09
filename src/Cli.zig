const std = @import("std");
const Allocator = std.mem.Allocator;

const openapi = @import("openapi.zig");
const sliceEql = @import("util.zig").sliceEql;
const _target = @import("target.zig");
const Target = _target.Target;
const Jsdoc = _target.Jsdoc;
const Typescript = _target.Typescript;

const stdout = std.io.getStdOut().writer();

const Output = struct {
    num_types: usize,
    str: []u8,
};

const Cli = @This();
allocator: std.mem.Allocator,
args: Args,
output: ?Output,

pub fn init(allocator: Allocator, args_in: []const []const u8) !Cli {
    // Skip the first argument, which is the program name.
    const args = args_in[1..];
    const args_struct = try Args.init(args);

    return Cli{
        .allocator = allocator,
        .args = args_struct,
        .output = null,
    };
}

pub fn generate(self: *Cli, input_file: std.fs.File) !Output {
    const stat = try input_file.stat();
    const json_contents = try input_file.readToEndAlloc(self.allocator, stat.size);

    const target = self.args.target;
    const json = try std.json.parseFromSlice(std.json.Value, self.allocator, json_contents, .{});
    defer json.deinit();

    var contents = std.ArrayList([]const u8).init(self.allocator);
    defer contents.deinit();

    const schemas = json.value.object.get("components").?.object.get("schemas").?.object;
    for (schemas.keys(), schemas.values()) |key, value| {
        try contents.append(try target.buildTypedef(self.allocator, key, value));
    }

    const num_types = schemas.keys().len;
    const output_str = try std.mem.join(self.allocator, "\n", contents.items);

    return Output{ .num_types = num_types, .str = output_str };
}

const Args = struct {
    target: Target,
    input_file_path: []const u8,
    output_file_path: []const u8,

    pub fn init(args: []const []const u8) !Args {
        const processed_args = try Args.process(args);

        return Args{
            .target = processed_args.target,
            .input_file_path = processed_args.input_file_path,
            .output_file_path = processed_args.output_file_path,
        };
    }

    pub fn process(args: []const []const u8) !Args {
        var target: ?Target = null;
        var input_file_path: ?[]const u8 = null;
        var output_file_path: ?[]const u8 = null;

        for (args) |arg| {
            if (sliceEql(arg, "-h") or sliceEql(arg, "-help")) {
                try Args.help();
                std.process.cleanExit();
            } else if (sliceEql(arg, "-target=jsdoc")) {
                target = Target{ .jsdoc = Jsdoc{} };
            } else if (sliceEql(arg, "-target=ts") or sliceEql(arg, "-target=typescript")) {
                target = Target{ .typescript = Typescript{} };
            } else if (input_file_path == null) {
                input_file_path = arg;
            } else if (output_file_path == null) {
                output_file_path = arg;
            } else {
                try Args.help();
                return error.InvalidArgument;
            }
        }

        if (target == null or input_file_path == null or output_file_path == null) {
            try Args.help();
            return error.InvalidArgument;
        }

        return Args{
            .target = target.?,
            .input_file_path = input_file_path.?,
            .output_file_path = output_file_path.?,
        };
    }

    pub fn help() !void {
        try stdout.print(
            "Usage: openapi-typegen -target=<jsdoc|ts> <input_file_path> <output_file_path>\n",
            .{},
        );
    }
};
