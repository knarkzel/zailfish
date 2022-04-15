const std = @import("std");
const print = std.debug.print;

fn template(comptime context: type) void {
    print("\n", .{});
    inline for (@typeInfo(context).Struct.fields) |field| {
        print("{s}: {s}\n", .{ field.name, field.field_type });
    }
}

fn string(input: []const u8) ?[]const u8 {
    for (input) |c, i| {
        if (c == '{') {
            return input[0..i];
        }
    }
    return null;
}

fn delimiter(input: []const u8) ?[]const u8 {
    for (input) |start, i| {
        if (start == '{') {
            for (input[i..]) |end, j| {
                if (end == '}') {
                    return input[i .. i + j + 1];
                }
            }
        }
    }
    return null;
}

test "basic add functionality" {
    const input = @embedFile("../templates/index.html");
    template(struct { name: []const u8 });
    if (delimiter(input)) |block| {
        print("{s}\n", .{block});
    }
}
