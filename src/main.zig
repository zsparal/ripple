const std = @import("std");
const io = @import("./io.zig");
const linux = std.os.linux;
const posix = std.posix;
const c = @cImport({
    @cInclude("arpa/inet.h");
});

const SPLICE_F_NONBLOCK = 2;

pub fn main() !void {
    var ioRing = try io.IO.init();
    defer ioRing.deinit();

    for (0..10) |i| {
        try ioRing.runOnce(i);
    }
}

// pub fn main() !void {
//     // var ring = try io.IO.init(32);
//     // defer ring.deinit();
//
//     // try ring.sendHelloWorld();
//     // try ring.sendHelloWorld();
//     // try ring.sendHelloWorld();
//     // try ring.sendHelloWorld();
//     // try ring.sendHelloWorld();
//     // try ring.sendHelloWorld();
// }
