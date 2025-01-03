const std = @import("std");

pub fn parse_linux_version(uname: []const u8) !std.SemanticVersion {
    const release = blk: {
        var version_end: u64 = 0;
        var dots_found: u64 = 0;

        for (uname) |c| {
            if (c == '.') {
                dots_found += 1;
            }

            if (dots_found == 3) {
                break;
            }

            if (c == '.' or std.ascii.isDigit(c)) {
                version_end += 1;
                continue;
            }

            break;
        }

        break :blk uname[0..version_end];
    };

    return std.SemanticVersion.parse(release);
}
