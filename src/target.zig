const std = @import("std");
const openapi = @import("openapi.zig");
const util = @import("util.zig");
const sliceEql = util.sliceEql;
const Allocator = std.mem.Allocator;
const stdout = std.io.getStdOut().writer();

pub const Target = union(enum) {
    jsdoc: Jsdoc,
    typescript: Typescript,

    pub fn buildTypedef(
        self: Target,
        allocator: Allocator,
        schema_key: []const u8,
        schema_object: std.json.Value,
    ) ![]u8 {
        return switch (self) {
            inline else => |target| {
                return try target.buildTypedef(allocator, schema_key, schema_object);
            },
        };
    }
};

pub const Jsdoc = struct {
    pub fn buildTypedef(
        self: Jsdoc,
        allocator: Allocator,
        schema_key: []const u8,
        schema_object: std.json.Value,
    ) ![]u8 {
        _ = self; // autofix
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

            if (openapi.isPropertyRequired(schema_object, key)) {
                try output.append(key);
            } else {
                try output.append("[");
                try output.append(key);
                try output.append("]");
            }

            try output.append("\n");
        }
        try output.append(" */\n");

        const output_str = try std.mem.join(allocator, "", output.items);
        try stdout.print("JSDoc Typedef: {s}\n", .{output_str});

        return output_str;
    }

    fn get_jsdoc_type(
        allocator: std.mem.Allocator,
        value: std.json.Value,
        array_suffix: []const u8,
    ) ![]const u8 {
        if (value.object.get("enum")) |enum_| {
            const enum_values = enum_.array.items;
            var output = std.ArrayList([]const u8).init(allocator);
            defer output.deinit();

            for (enum_values) |enum_value| {
                try output.append(
                    try std.fmt.allocPrint(
                        allocator,
                        "\"{s}\"",
                        .{enum_value.string},
                    ),
                );
            }

            return try std.mem.join(allocator, " | ", output.items);
        }
        if (value.object.get("type")) |type_| {
            if (sliceEql(type_.string, "array")) {
                const items = value.object.get("items").?;
                const item_type = try get_jsdoc_type(allocator, items, "[]");
                return item_type;
            }

            var type_str = type_.string;
            if (sliceEql(type_str, "integer")) {
                type_str = "number";
            }

            return try std.fmt.allocPrint(allocator, "{s}{s}", .{ type_str, array_suffix });
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
};

pub const Typescript = struct {
    pub fn buildTypedef(
        self: Typescript,
        allocator: Allocator,
        schema_key: []const u8,
        schema_object: std.json.Value,
    ) ![]u8 {
        _ = self; // autofix
        var output = std.ArrayList([]const u8).init(allocator);
        defer output.deinit();

        try output.append("type ");
        const type_key = try TypeKey.init(allocator, schema_key);
        try output.append(type_key.value);
        try output.append(" = {\n");

        const properties = schema_object.object.get("properties").?.object;

        for (properties.keys(), properties.values()) |key, value| {
            try output.append("  ");
            const prop_key = try TypeKey.init(allocator, key);
            try output.append(prop_key.value);
            if (!openapi.isPropertyRequired(schema_object, key)) {
                try output.append("?");
            }
            try output.append(": ");
            const type_ = try get_typescript_type(allocator, value, "");
            try output.append(type_);

            try output.append(";\n");
        }
        try output.append("}\n");

        const output_str = try std.mem.join(allocator, "", output.items);
        try stdout.print("{s}\n", .{output_str});

        return output_str;
    }

    fn get_typescript_type(
        allocator: std.mem.Allocator,
        value: std.json.Value,
        array_suffix: []const u8,
    ) ![]const u8 {
        if (value.object.get("enum")) |enum_| {
            const enum_values = enum_.array.items;
            var output = std.ArrayList([]const u8).init(allocator);
            defer output.deinit();

            for (enum_values) |enum_value| {
                try output.append(
                    try std.fmt.allocPrint(allocator, "\"{s}\"", .{enum_value.string}),
                );
            }

            return try std.mem.join(allocator, " | ", output.items);
        }
        if (value.object.get("type")) |type_| {
            if (sliceEql(type_.string, "array")) {
                const items = value.object.get("items").?;
                const item_type = try get_typescript_type(allocator, items, "[]");
                return item_type;
            }

            var type_key = try TypeKey.init(allocator, type_.string);
            if (sliceEql(type_key.value, "integer")) {
                type_key.value = "number";
            }

            return try std.fmt.allocPrint(
                allocator,
                "{s}{s}",
                .{ type_key.value, array_suffix },
            );
        } else {
            const ref = value.object.get("$ref").?.string;
            var split = std.mem.split(u8, ref, "/");
            var key: []const u8 = undefined;
            while (split.next()) |part| {
                key = part;
            }
            const ref_key = try TypeKey.init(allocator, key);
            return try std.fmt.allocPrint(allocator, "{s}{s}", .{ ref_key.value, array_suffix });
        }
    }
};

const TypeKey = struct {
    value: []const u8,

    pub fn init(allocator: Allocator, value: []const u8) !TypeKey {
        var type_key = TypeKey{ .value = undefined };
        type_key.value = try TypeKey.cleanTypeName(allocator, value);
        return type_key;
    }

    pub fn cleanTypeName(allocator: Allocator, type_name: []const u8) ![]const u8 {
        var buf = try allocator.alloc(u8, type_name.len);
        var buf_len: u8 = 0;

        for (type_name) |c| {
            if (isAllowedChar(c)) {
                buf[buf_len] = c;
                buf_len += 1;
            }
        }

        return buf[0..buf_len];
    }

    fn isAllowedChar(c: u8) bool {
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            (c == '_');
    }
};
