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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var splits = std.mem.split(u8, input, "\n");
    var partOneSum: u32 = 0;
    var partTwoSum: u32 = 0;
    var lineBuf = [_]u8{ '0', '0' };

    while (splits.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        lineBuf[0] = try getDigit(line, false, false);
        lineBuf[1] = try getDigit(line, true, false);
        partOneSum += try std.fmt.parseInt(u8, &lineBuf, 10);

        lineBuf[0] = try getDigit(line, false, true);
        lineBuf[1] = try getDigit(line, true, true);
        partTwoSum += try std.fmt.parseInt(u8, &lineBuf, 10);
    }

    std.debug.print("Part One: {d}\nPart Two: {d}\n", .{ partOneSum, partTwoSum });
}

fn getDigit(slice: []const u8, comptime reverse: bool, comptime includeWords: bool) !u8 {
    const zeroChar = '0';
    const iter = comptime if (reverse) std.math.sub else std.math.add;

    var i: usize = if (reverse) slice.len - 1 else 0;
    return while (i >= 0 and i < slice.len) : (i = try iter(usize, i, 1)) {
        if (slice[i] - zeroChar < 10) {
            break slice[i];
        }

        if (includeWords) {
            for (stringDigits, 0..) |stringDigit, digit| {
                if (std.mem.startsWith(u8, slice[i..], stringDigit)) {
                    return @intCast(digit + zeroChar + 1);
                }
            }
        }
    } else {
        std.debug.print("Failed on this line: {s}", .{slice});
        unreachable;
    };
}
