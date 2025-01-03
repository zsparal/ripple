const std = @import("std");
const net = std.net;

// These are indexes of a registered descriptors in the _current_ IO instance.
// It is _NOT_ safe to share & use between different IO instances.
pub const SocketIndex = enum(i32) { _ };
pub const FileIndex = enum(i32) { _ };
pub const PipeIndex = enum(i32) { _ };

// These are descriptors that can be used for their respective type of operations directly.
// It is safe to share between IO instances but only a single IO instance may perform operations
// on a descriptor at the same time
pub const SocketDescriptor = enum(i32) { _ };
pub const FileDescriptor = enum(i32) { _ };
pub const PipeDescriptor = enum(i32) { _ };

pub const Socket = struct {
    protocol: Protocol,
    address: net.Ip4Address,
    socket: SocketIndex,

    pub const Protocol = enum(u1) {
        tcp,
        udp,
    };
};

pub const AcceptMany = struct {
    socket: SocketIndex,
};
