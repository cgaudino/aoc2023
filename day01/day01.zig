const std = @import("std");

const stringDigits = [_][]const u8{
    "one",
    "two",
    "three",
    "four",
    "five",
    "six",
    "seven",
    "eight",
    "nine",
};

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const alloc = std.heap.page_allocator;

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var splits = std.mem.split(u8, input, "\n");
    var count: u16 = 0;
    var lineBuf: [2]u8 = [_]u8{ '0', '0' };
    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        lineBuf[0] = try getDigit(line, false);
        lineBuf[1] = try getDigit(line, true);

        const lineValue = try std.fmt.parseInt(u8, &lineBuf, 10);
        count += lineValue;
    }

    std.debug.print("{d}\n", .{count});
}

fn getDigit(slice: []const u8, comptime reverse: bool) !u8 {
    const condition = if (reverse) greaterThanZero else lessThanLast;
    const iter = if (reverse) decrement else increment;
    var i: usize = if (reverse) slice.len - 1 else 0;
    const charOffset = 48;

    return while (condition(slice, i)) : (i = iter(i)) {
        if (slice[i] - charOffset < 10) {
            break slice[i];
        }

        const stringDigit = matchStringDigit(slice[i..]);
        if (stringDigit != null) {
            return @intCast(stringDigit.? + charOffset);
        }
    } else {
        std.debug.print("Failed on this line: {s}", .{slice});
        unreachable;
    };
}

fn matchStringDigit(slice: []const u8) ?usize {
    for (stringDigits, 0..) |digit, i| {
        if (std.mem.startsWith(u8, slice, digit)) {
            return i + 1;
        }
    }
    return null;
}

fn increment(i: usize) usize {
    return i + 1;
}
fn decrement(i: usize) usize {
    return i - 1;
}
fn greaterThanZero(_: []const u8, i: usize) bool {
    return i >= 0;
}
fn lessThanLast(slice: []const u8, i: usize) bool {
    return i < slice.len;
}
