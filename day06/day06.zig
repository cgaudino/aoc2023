const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const alloc = std.heap.page_allocator;

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');

    var timesIter = getNumIter(linesIter.next().?);
    var distancesIter = getNumIter(linesIter.next().?);

    var timeTextBuf = try std.ArrayList(u8).initCapacity(alloc, 32);
    defer timeTextBuf.deinit();
    var distanceTextBuf = try std.ArrayList(u8).initCapacity(alloc, 32);
    defer distanceTextBuf.deinit();

    var partOne: usize = 1;
    while (timesIter.next()) |timeText| {
        const distanceText = distancesIter.next().?;

        const time = try std.fmt.parseInt(usize, timeText, 10);
        const distance = try std.fmt.parseInt(usize, distanceText, 10);

        try timeTextBuf.appendSlice(timeText);
        try distanceTextBuf.appendSlice(distanceText);

        var possibleWins: usize = 0;
        for (1..time) |i| {
            if (i * (time - i) > distance) {
                possibleWins += 1;
            }
        }
        partOne *= possibleWins;
    }
    std.debug.print("Part One: {d}\n", .{partOne});

    var partTwo: usize = 0;
    const longTime = try std.fmt.parseInt(usize, timeTextBuf.items, 10);
    const longDistance = try std.fmt.parseInt(usize, distanceTextBuf.items, 10);
    for (1..longTime) |i| {
        if (i * (longTime - i) > longDistance) {
            partTwo += 1;
        }
    }
    std.debug.print("Part Two: {d}\n", .{partTwo});
}

fn getNumIter(line: []const u8) std.mem.TokenIterator(u8, .scalar) {
    const colonIndex = std.mem.indexOfScalar(u8, line, ':').?;
    return std.mem.tokenizeScalar(u8, line[colonIndex + 1 ..], ' ');
}
