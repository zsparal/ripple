const std = @import("std");
const linux = std.os.linux;
const posix = std.posix;
const net = std.net;

// A strongly-typed socket descriptor that can be used in various IO-calls involving sockets
pub const SocketDescriptor = enum(i32) { _ };

// A strongly-typed file descriptor that can be used in various file-system operations
pub const FileDescriptor = enum(i32) { _ };

// A strongly-typed pipe descriptor for pipe operations
pub const PipeDescriptor = enum(i32) { _ };

pub const SocketType = enum(u1) {
    tcp,
    udp,
};

pub const CreateSocket = struct {
    descriptor: SocketDescriptor,
    address: net.Ip4Address,
    socket_type: SocketType,
};

const r = linux.IoUring.init(16, 0) catch unreachable();
