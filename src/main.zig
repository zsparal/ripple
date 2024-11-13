const std = @import("std");
const io = @import("./io.zig");

pub fn main() !void {
    var ring = try io.IO.init(128);
    defer ring.deinit();

    try ring.sendHelloWorld();
}
