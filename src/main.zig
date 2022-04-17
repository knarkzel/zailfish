const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ComptimeArrayList = @import("comptime-arraylist.zig").ComptimeArrayList;

const Token = union(enum) { string: []const u8, block: []const u8 };

// Takes until {{
fn string(input: []const u8) ?Token {
    for (input) |c, i| {
        if (c == '{') return Token{ .string = input[0..i] };
    } else return Token{ .string = input };
}

// Looks for {{ <block> }}
fn block(input: []const u8) ?Token {
    if (input[0] == '{') for (input) |c, i| {
        if (c == '}') return Token{ .block = input[0 .. i + 1] };
    };
    return null;
}

fn parse(comptime input: []const u8) []const Token {
    comptime {
        var cursor: usize = 0;
        var tokens: []const Token = &.{};
        while (cursor < input.len) {
            if (block(input[cursor..])) |token| {
                cursor += token.block.len;
                const result = Token{ .block = std.mem.trim(u8, token.block, " \n{}") };
                tokens = tokens ++ [_]Token{result};
            } else if (string(input[cursor..])) |token| {
                cursor += token.string.len;
                tokens = tokens ++ [_]Token{token};
            } else break;
        }
        return tokens;
    }
}

fn template(input: []const u8, comptime context: type) fn (Allocator, anytype) anyerror![]const u8 {
    const tokens = parse(input);
    return struct {
        fn result(allocator: Allocator, runtime: anytype) anyerror![]const u8 {
            var output = ArrayList(u8).init(allocator);
            tokens: for (tokens) |token| switch (token) {
                .block => |inner| {
                    // Find matching field in context then pass it
                    inline for (@typeInfo(context).Struct.fields) |field| {
                        if (std.mem.eql(u8, field.name, inner)) {
                            const slice = try std.fmt.allocPrint(allocator, "{s}", .{@field(runtime, field.name)});
                            try output.appendSlice(slice);
                            continue :tokens;
                        }
                    }
                },
                .string => |inner| try output.appendSlice(inner),
            };
            return std.fmt.allocPrint(allocator, "\n{s}\n", .{output.items});
        }
    }.result;
}

test "template" {
    // Create template function then call it and print
    var allocator = ArenaAllocator.init(std.heap.page_allocator).allocator();
    const input = @embedFile("../templates/index.html");
    const index_template = template(input, struct { name: []const u8 });
    const result = try index_template(allocator, .{ .name = "hello bro" });
    print("{s}", .{result});
}
