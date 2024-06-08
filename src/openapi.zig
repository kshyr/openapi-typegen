const std = @import("std");

pub fn isPropertyRequired(schema_object: std.json.Value, property_key: []const u8) bool {
    const required = schema_object.object.get("required") orelse return false;

    for (required.array.items) |required_key| {
        if (std.mem.eql(u8, required_key.string, property_key)) {
            return true;
        }
    }
    return false;
}
