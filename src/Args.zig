const std = @import("std");
const _target = @import("target.zig");
const Target = _target.Target;
const Jsdoc = _target.Jsdoc;
const Typescript = _target.Typescript;
const sliceEql = @import("util.zig").sliceEql;

const stdout = std.io.getStdOut().writer();

const Args = @This();
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
