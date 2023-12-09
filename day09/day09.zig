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
        const extrapolations = try extrapolate(numbers.items, arenaAlloc);
        partOneSum += extrapolations.end;
        partTwoSum += extrapolations.start;

        _ = arena.reset(.retain_capacity);
    }
    std.debug.print("Part One: {d}\nPart Two: {d}\n", .{ partOneSum, partTwoSum });
}

fn extrapolate(numbers: []i64, allocator: std.mem.Allocator) !struct { start: i64, end: i64 } {
    if (std.mem.allEqual(i64, numbers, 0)) {
        return .{ .start = 0, .end = 0 };
    }

    var diffs = try allocator.alloc(i64, numbers.len - 1);
    for (diffs, 0..) |_, i| {
        diffs[i] = numbers[i + 1] - numbers[i];
    }

    const next = try extrapolate(diffs, allocator);
    return .{ .start = numbers[0] - next.start, .end = numbers[numbers.len - 1] + next.end };
}
