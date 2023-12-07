const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');

    var timesIter = getNumIter(linesIter.next().?);
    var distancesIter = getNumIter(linesIter.next().?);

    var timeTextBuf = try std.ArrayList(u8).initCapacity(alloc, 32);
    defer timeTextBuf.deinit();
    var distanceTextBuf = try std.ArrayList(u8).initCapacity(alloc, 32);
    defer distanceTextBuf.deinit();

    var partOne: u64 = 1;
    while (timesIter.next()) |timeText| {
        const distanceText = distancesIter.next().?;

        const time = try std.fmt.parseFloat(f64, timeText);
        const distance = try std.fmt.parseFloat(f64, distanceText);

        partOne *= calcPossibleWins(time, distance);

        try timeTextBuf.appendSlice(timeText);
        try distanceTextBuf.appendSlice(distanceText);
    }
    std.debug.print("Part One: {d}\n", .{partOne});

    const longTime = try std.fmt.parseFloat(f64, timeTextBuf.items);
    const longDistance = try std.fmt.parseFloat(f64, distanceTextBuf.items);
    const partTwo = calcPossibleWins(longTime, longDistance);
    std.debug.print("Part Two: {d}\n", .{partTwo});
}

fn getNumIter(line: []const u8) std.mem.TokenIterator(u8, .scalar) {
    const colonIndex = std.mem.indexOfScalar(u8, line, ':').?;
    return std.mem.tokenizeScalar(u8, line[colonIndex + 1 ..], ' ');
}

fn calcPossibleWins(time: f64, distance: f64) u64 {
    const sqrt = @sqrt(time * time - 4.0 * (-1.0) * (-distance));
    const solutionA = @ceil((-time + sqrt) / -2.0);
    const solutionB = @floor((-time - sqrt) / -2.0);
    const range: u64 = @intFromFloat(@abs((solutionA - solutionB)));
    return range + 1;
}
