const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var arena = std.heap.ArenaAllocator.init(alloc);
    const arenaAlloc = arena.allocator();
    defer arena.deinit();

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');
    var partOneSum: i64 = 0;
    var partTwoSum: i64 = 0;
    while (lineIter.next()) |line| {
        var numIter = std.mem.tokenizeScalar(u8, line, ' ');
        var numbers = try std.ArrayList(i64).initCapacity(arenaAlloc, 50);
        while (numIter.next()) |num| {
            try numbers.append(try std.fmt.parseInt(i64, num, 10));
        }

        partOneSum += try extrapolate(i64, numbers.items, arenaAlloc, false);
        partTwoSum += try extrapolate(i64, numbers.items, arenaAlloc, true);

        _ = arena.reset(.retain_capacity);
    }
    std.debug.print("Part One: {d}\nPart Two: {d}\n", .{ partOneSum, partTwoSum });
}

fn extrapolate(comptime T: type, numbers: []T, allocator: std.mem.Allocator, comptime reverse: bool) !T {
    if (std.mem.allEqual(T, numbers, 0)) {
        return 0;
    }

    var diffs: []T = try allocator.alloc(T, numbers.len - 1);
    for (diffs, 0..) |_, i| {
        diffs[i] = numbers[i + 1] - numbers[i];
    }

    if (reverse) {
        return numbers[0] - try extrapolate(T, diffs, allocator, reverse);
    }
    return numbers[numbers.len - 1] + try extrapolate(T, diffs, allocator, reverse);
}
