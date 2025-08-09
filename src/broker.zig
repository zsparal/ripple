const std = @import("std");

const ripple = @import("ripple");

pub fn main() !void {
    var stdout_buffer: [1024]u8 = undefined;

    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try stdout.flush();
}

comptime {
    @import("std").testing.refAllDeclsRecursive(@This());
}

test "simple test" {
    const allocator = std.testing.allocator;
    var list = try std.ArrayList(i32).initCapacity(allocator, 1);
    defer list.deinit(allocator); // try commenting this out and see if zig detects the memory leak!
    try list.append(allocator, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
