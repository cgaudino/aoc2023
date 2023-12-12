const std = @import("std");

const Galaxy = @Vector(2, i64);

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');

    var galaxies = try std.ArrayList(Galaxy).initCapacity(alloc, 1024);
    defer galaxies.deinit();

    var yExpansionAccum: i64 = 0;
    var yExpansions = try std.ArrayList(i64).initCapacity(alloc, 1024);
    defer yExpansions.deinit();

    var xExpansionAccum: i64 = 0;
    var xExpansions = try std.ArrayList(i64).initCapacity(alloc, 1024);
    try xExpansions.appendNTimes(0, linesIter.peek().?.len);
    defer xExpansions.deinit();

    var y: i32 = 0;
    while (linesIter.next()) |line| : (y += 1) {
        var rowHasGalaxy = false;
        for (line, 0..) |char, x| {
            switch (char) {
                '.' => {},
                '#' => {
                    rowHasGalaxy = true;
                    xExpansions.items[x] = 1;
                    try galaxies.append(.{ @intCast(x), @intCast(y) });
                },
                else => unreachable,
            }
        }
        if (!rowHasGalaxy) {
            yExpansionAccum += 1;
        }
        try yExpansions.append(yExpansionAccum);
    }

    for (xExpansions.items, 0..) |val, i| {
        if (val == 0) {
            xExpansionAccum += 1;
        }
        xExpansions.items[i] = xExpansionAccum;
    }

    std.debug.print("Part One: {d}\n", .{sumShortestPaths(galaxies.items, 1, xExpansions.items, yExpansions.items)});
    std.debug.print("Part Two: {d}\n", .{sumShortestPaths(galaxies.items, 1_000_000, xExpansions.items, yExpansions.items)});
}

fn sumShortestPaths(galaxies: []const Galaxy, expansionFactor: i64, xExpansions: []const i64, yExpansions: []const i64) i64 {
    var distanceAccum: i64 = 0;
    var e = if (expansionFactor > 1) expansionFactor - 1 else expansionFactor;
    for (galaxies, 0..) |galaxy, index| {
        for ((index + 1)..(galaxies.len)) |otherIndex| {
            const otherGalaxy = galaxies[otherIndex];
            const xDistance = abs((galaxy[0] + xExpansions[@intCast(galaxy[0])] * e) - (otherGalaxy[0] + xExpansions[@intCast(otherGalaxy[0])] * e));
            const yDistance = abs((galaxy[1] + yExpansions[@intCast(galaxy[1])] * e) - (otherGalaxy[1] + yExpansions[@intCast(otherGalaxy[1])] * e));
            distanceAccum += xDistance + yDistance;
        }
    }
    return distanceAccum;
}

fn abs(a: anytype) @TypeOf(a) {
    if (a < 0) {
        return -a;
    }
    return a;
}
