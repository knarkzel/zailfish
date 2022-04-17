const std = @import("std");
const print = std.debug.print;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

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

fn parse(allocator: Allocator, input: []const u8) !ArrayList(Token) {
    var tokens = ArrayList(Token).init(allocator);
    var cursor: usize = 0;
    while (cursor < input.len) {
        if (block(input[cursor..])) |token| {
            cursor += token.block.len;
            const trimmed = std.mem.trim(u8, token.block, " \n{}");
            try tokens.append(Token{ .block = trimmed });
        } else if (string(input[cursor..])) |token| {
            cursor += token.string.len;
            try tokens.append(token);
        } else break;
    }
    return tokens;
}

fn template(allocator: Allocator, input: []const u8, comptime context: type, runtime: anytype) ![]const u8 {
    const tokens = try parse(allocator, input);
    var output = ArrayList(u8).init(allocator);
    tokens: for (tokens.items) |token| switch (token) {
        .block => |inner| {
            // Find matching field in context then pass it
            inline for (@typeInfo(context).Struct.fields) |field| {
                if (std.mem.eql(u8, field.name, inner)) {
                    const result = try std.fmt.allocPrint(allocator, "{s}", .{@field(runtime, field.name)});
                    try output.appendSlice(result);
                    continue :tokens;
                }
            }
        },
        .string => |inner| try output.appendSlice(inner),
    };
    return std.fmt.allocPrint(allocator, "\n{s}\n", .{output.items});
}

test "template" {
    // Allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Code
    const input = @embedFile("../templates/index.html");
    const Index = struct { name: []const u8 };
    const index = Index{ .name = "hello bro" };
    const output = try template(allocator, input, Index, index);
    print("\n{s}\n", .{output});
}

test "parser" {
    // Allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Code
    const input = @embedFile("../templates/index.html");
    const tokens = try parse(allocator, input);
    print("\n", .{});
    for (tokens.items) |token| switch (token) {
        .block => |inner| print("Block({s})\n", .{inner}),
        .string => |inner| print("String({s})\n", .{inner}),
    };
}
