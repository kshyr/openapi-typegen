const std = @import("std");

const stdout = std.io.getStdOut().writer();

fn build_output(allocator: std.mem.Allocator, json_contents: []u8) ![]u8 {
    const json = try std.json.parseFromSlice(std.json.Value, allocator, json_contents, .{});
    defer json.deinit();

    var contents = std.ArrayList([]const u8).init(allocator);
    defer contents.deinit();

    try stdout.print("Parsed JSON: {any}\n", .{json});

    const schemas = json.value.object.get("components").?.object.get("schemas").?.object;
    for (schemas.keys(), schemas.values()) |key, value| {
        try stdout.print("Schema: {s}\n", .{key});
        try contents.append(try build_jsdoc_typedef(allocator, key, value));
    }

    return std.mem.join(allocator, "\n", contents.items);
}

fn build_jsdoc_typedef(allocator: std.mem.Allocator, schema_key: []const u8, schema_object: std.json.Value) ![]u8 {
    var output = std.ArrayList([]const u8).init(allocator);
    defer output.deinit();

    try output.append("/**\n");
    try output.append(" * @typedef {Object} ");
    try output.append(schema_key);
    try output.append("\n");

    const properties = schema_object.object.get("properties").?.object;

    for (properties.keys(), properties.values()) |key, value| {
        try output.append(" * @property {");
        const type_ = try get_jsdoc_type(allocator, value, "");
        try output.append(type_);
        try output.append("} ");
        try output.append(key);
        try output.append("\n");
    }
    try output.append(" */\n");

    const output_str = try std.mem.join(allocator, "", output.items);
    try stdout.print("JSDoc Typedef: {s}\n", .{output_str});

    return output_str;
}

fn get_jsdoc_type(allocator: std.mem.Allocator, value: std.json.Value, array_suffix: []const u8) ![]const u8 {
    if (value.object.get("enum")) |enum_| {
        const enum_values = enum_.array.items;
        var output = std.ArrayList([]const u8).init(allocator);
        defer output.deinit();

        for (enum_values) |enum_value| {
            try output.append(try std.fmt.allocPrint(allocator, "\"{s}\"", .{enum_value.string}));
        }

        return try std.mem.join(allocator, " | ", output.items);
    }
    if (value.object.get("type")) |type_| {
        if (std.mem.eql(u8, type_.string, "array")) {
            const items = value.object.get("items").?;
            const item_type = try get_jsdoc_type(allocator, items, "[]");
            return item_type;
        } else if (std.mem.eql(u8, type_.string, "object")) {
            return "Object";
        } else if (std.mem.eql(u8, type_.string, "string")) {
            return "string";
        } else if (std.mem.eql(u8, type_.string, "number")) {
            return "number";
        } else if (std.mem.eql(u8, type_.string, "integer")) {
            return "number";
        } else if (std.mem.eql(u8, type_.string, "boolean")) {
            return "boolean";
        }
        return try std.fmt.allocPrint(allocator, "{s}{s}", .{ type_.string, array_suffix });
    } else {
        const ref = value.object.get("$ref").?.string;
        var split = std.mem.split(u8, ref, "/");
        var ref_key: []const u8 = undefined;
        while (split.next()) |part| {
            ref_key = part;
        }
        return try std.fmt.allocPrint(allocator, "{s}{s}", .{ ref_key, array_suffix });
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args_with_exe = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args_with_exe);
    const args = args_with_exe[1..]; // remove the executable name

    if (args.len != 2 or std.mem.eql(u8, args[0], "help")) {
        try stdout.print("Usage: openapi-to-jsdoc <input_file> <output_file>\n", .{});
    }

    const input_file = try std.fs.cwd().openFile(args[0], .{ .mode = .read_only });
    defer input_file.close();

    const stat = try input_file.stat();
    const input_contents = try input_file.readToEndAlloc(allocator, stat.size);

    const output_file = try std.fs.cwd().createFile(args[1], .{});
    defer output_file.close();

    const output_str = try build_output(allocator, input_contents);

    try output_file.writeAll(output_str);

    try stdout.print("Successfully written JSDoc typedefs to {s}.\n", .{args[1]});
}
