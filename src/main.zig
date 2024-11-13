const std = @import("std");
const os = std.os;
const posix = std.posix;
const linux = os.linux;
const allocator = std.heap.PageAllocator;

const c = @cImport({
    @cInclude("arpa/inet.h");
});

fn sendFile(socket_index: comptime_int, file_index: comptime_int, task_id: *u64, file_pipe: [2]posix.fd_t, ring: *linux.IoUring, path: [*:0]const u8) !void {
    const file = try ring.openat_direct(task_id.*, posix.AT.FDCWD, path, .{ .NONBLOCK = true }, 0, file_index);
    file.flags |= linux.IOSQE_IO_LINK;
    task_id.* += 1;

    const splice_read = try ring.splice(task_id.*, file_index, 0, file_pipe[1], std.math.maxInt(u64), 13);
    splice_read.flags |= linux.IOSQE_IO_LINK;
    splice_read.rw_flags |= linux.IORING_SPLICE_F_FD_IN_FIXED;
    task_id.* += 1;

    const splice_write = try ring.splice(task_id.*, file_pipe[0], std.math.maxInt(u64), socket_index, std.math.maxInt(u64), 13);
    splice_write.flags |= linux.IOSQE_IO_LINK | linux.IOSQE_FIXED_FILE;
    splice_read.rw_flags |= linux.IORING_SPLICE_F_FD_IN_FIXED;
    task_id.* += 1;
}

pub fn main() !void {
    var task_id: u64 = 0;
    var ring = try linux.IoUring.init(32, 0);
    defer ring.deinit();

    const file_pipe = try posix.pipe2(.{ .NONBLOCK = true });

    // Register files
    const files = [_]posix.fd_t{-1} ** 8;
    try ring.register_files(&files);

    const socket_index = 0;
    const file_index = 1;

    const socket = try ring.socket_direct(task_id, posix.AF.INET, posix.SOCK.STREAM | posix.SOCK.NONBLOCK, 0, 0, socket_index);
    socket.flags |= linux.IOSQE_IO_LINK;
    task_id += 1;

    const sock_addr = posix.sockaddr.in{ .port = c.htons(9000), .addr = c.inet_addr("127.0.0.1") };
    const connect = try ring.connect(task_id, socket_index, @ptrCast(&sock_addr), @sizeOf(@TypeOf(sock_addr)));
    connect.flags |= linux.IOSQE_IO_LINK | linux.IOSQE_FIXED_FILE;
    task_id += 1;

    try sendFile(socket_index, file_index, &task_id, file_pipe, &ring, "./test.txt");
    try sendFile(socket_index, file_index, &task_id, file_pipe, &ring, "./test2.txt");

    _ = try ring.close_direct(task_id, socket_index);
    task_id += 1;

    _ = try ring.submit();

    var remaining = task_id;
    var max_cqe_buffer: [32]linux.io_uring_cqe = undefined;

    while (remaining != 0) {
        const tasks = max_cqe_buffer[0..remaining];
        const resolved = try ring.copy_cqes(tasks, @intCast(task_id));

        for (tasks[0..resolved]) |task| {
            std.debug.print("{any}\n", .{task});
        }
        remaining -= resolved;
    }
}
