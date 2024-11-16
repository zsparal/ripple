const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const assert = std.debug.assert;

const stdx = @import("stdx.zig");

const SPLICE_F_NONBLOCK = 2;

pub const IO = struct {
    ring: linux.IoUring,

    pub fn init() !IO {
        const version = try stdx.parse_linux_version(&posix.uname().release);
        assert(version.order(std.SemanticVersion{ .major = 6, .minor = 1, .patch = 0 }) != .lt);

        const flags = linux.IORING_SETUP_SINGLE_ISSUER | linux.IORING_SETUP_DEFER_TASKRUN;
        var ring = try linux.IoUring.init(16, flags);

        const files = [_]posix.fd_t{-1} ** 8;
        try ring.register_files(&files);

        return IO{ .ring = ring };
    }

    pub fn deinit(io: *IO) void {
        io.ring.deinit();
    }

    pub fn runOnce(self: *IO, i: usize) !void {
        const ring = &self.ring;

        var task_id: u64 = 0;
        const socket_index = 0;
        const file_index = 1;
        const file_pipe = .{ 2, 3 };

        try ring.register_files_update(file_pipe[0], &try posix.pipe2(.{ .NONBLOCK = true }));

        const socket = try ring.socket_direct(task_id, posix.AF.INET, posix.SOCK.STREAM | posix.SOCK.NONBLOCK, 0, 0, socket_index);
        socket.flags |= linux.IOSQE_IO_LINK;
        task_id += 1;

        const ipv4 = try std.net.Ip4Address.parse("127.0.0.1", 9000);
        const sock_addr = ipv4.sa;
        const connect = try ring.connect(task_id, socket_index, @ptrCast(&sock_addr), @sizeOf(@TypeOf(sock_addr)));
        connect.flags |= linux.IOSQE_IO_LINK | linux.IOSQE_FIXED_FILE;
        task_id += 1;

        try self.sendFile(socket_index, file_index, &task_id, file_pipe, "./test.txt");
        try self.sendFile(socket_index, file_index, &task_id, file_pipe, "./test2.txt");

        const shutdown = try ring.shutdown(task_id, socket_index, linux.SHUT.WR);
        shutdown.flags |= linux.IOSQE_IO_LINK | linux.IOSQE_FIXED_FILE;
        task_id += 1;

        var remaining = try ring.submit_and_wait(@intCast(task_id));
        var max_cqe_buffer: [32]linux.io_uring_cqe = undefined;

        while (remaining != 0) {
            const tasks = max_cqe_buffer[0..remaining];
            const resolved = try ring.copy_cqes(tasks, remaining);
            std.debug.print("({}) Processing batch of {} tasks\n", .{ i, resolved });

            for (tasks[0..resolved]) |task| {
                std.debug.print("{any}\n", .{task});
            }
            remaining -|= resolved;
        }
    }

    fn sendFile(
        io: *IO,
        socket_index: comptime_int,
        file_index: comptime_int,
        task_id: *u64,
        file_pipe: [2]posix.fd_t,
        path: [*:0]const u8,
    ) !void {
        const ring = &io.ring;

        const file = try ring.openat_direct(task_id.*, posix.AT.FDCWD, path, .{ .NONBLOCK = true }, 0, file_index);
        file.flags |= linux.IOSQE_IO_LINK;
        task_id.* += 1;

        const splice_read = try ring.splice(task_id.*, file_index, 0, file_pipe[1], std.math.maxInt(u64), 13);
        splice_read.flags |= linux.IOSQE_IO_LINK | linux.IOSQE_FIXED_FILE;
        splice_read.rw_flags |= linux.IORING_SPLICE_F_FD_IN_FIXED | SPLICE_F_NONBLOCK;
        task_id.* += 1;

        const splice_write = try ring.splice(task_id.*, file_pipe[0], std.math.maxInt(u64), socket_index, std.math.maxInt(u64), 13);
        splice_write.flags |= linux.IOSQE_IO_LINK | linux.IOSQE_FIXED_FILE;
        splice_write.rw_flags |= linux.IORING_SPLICE_F_FD_IN_FIXED | SPLICE_F_NONBLOCK;
        task_id.* += 1;
    }
};
