const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const alloc = std.heap.page_allocator;

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var winningNumbers = std.AutoArrayHashMap(u16, void).init(alloc);
    defer winningNumbers.clearAndFree();

    var pointsSum: u32 = 0;
    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (linesIter.next()) |line| {
        var headerEndIndex = std.mem.indexOfScalar(u8, line, ':');
        var dividerIndex = std.mem.indexOfScalar(u8, line, '|');

        const winningNumList = line[(headerEndIndex.? + 1)..dividerIndex.?];
        const matchNumList = line[(dividerIndex.? + 1)..];

        winningNumbers.clearRetainingCapacity();
        var winningNumbersIter = std.mem.tokenizeScalar(u8, winningNumList, ' ');
        while (winningNumbersIter.next()) |number| {
            const value = std.fmt.parseInt(u16, number, 10) catch |err| {
                std.debug.print("Failed on {s}\n", .{number});
                return err;
            };
            try winningNumbers.put(value, {});
        }

        var matches: u16 = 0;
        var matchNumbersIter = std.mem.tokenizeScalar(u8, matchNumList, ' ');
        while (matchNumbersIter.next()) |number| {
            const value = std.fmt.parseInt(u16, number, 10) catch |err| {
                std.debug.print("Failed on {s}\n", .{number});
                return err;
            };
            if (winningNumbers.contains(value)) {
                matches += 1;
            }
        }

        if (matches > 0) {
            pointsSum += std.math.pow(u32, 2, matches - 1);
        }
    }

    std.debug.print("Part One: {d}\n", .{pointsSum});
}
