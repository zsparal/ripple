const builtin = @import("builtin");

pub const IO = switch (builtin.target.os.tag) {
    .linux => @import("io/linux.zig").IO,
    else => @compileError("IO is not yet supported for this platform"),
};

