const std = @import("std");

pub const OpenApi = struct {
    schemas: std.ArrayHashMap(
        []const u8,
        std.json.Value,
        std.array_hash_map.StringContext,
        true,
    ),

    pub fn init(json: std.json.Value) OpenApi {
        const schemas = json.object.get("components").?.object.get("schemas").?.object;
        std.debug.print("schemas: {any}\n", .{@TypeOf(schemas)});
        return OpenApi{
            .schemas = schemas,
        };
    }
};

pub fn isPropertyRequired(schema_object: std.json.Value, property_key: []const u8) bool {
    const required = schema_object.object.get("required") orelse return false;

    for (required.array.items) |required_key| {
        if (std.mem.eql(u8, required_key.string, property_key)) {
            return true;
        }
    }
    return false;
}

pub fn getEnumValues(schema_object: std.json.Value) ?[]const std.json.Value {
    const enum_values = schema_object.object.get("enum") orelse return null;
    return enum_values.array.items;
}
