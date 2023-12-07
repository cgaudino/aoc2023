const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    defer {
        const nsElapsed = timer.read();
        const seconds = nsElapsed / std.time.ns_per_s;
        const ms = (nsElapsed % std.time.ns_per_s) / std.time.ns_per_ms;
        std.debug.print("Ran in {d}sec, {d}ms\n", .{ seconds, ms });
    }

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const alloc = std.heap.page_allocator;

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var lines = std.mem.splitScalar(u8, input, '\n');

    const seedsLine = lines.next().?;
    _ = lines.next(); // blank line

    var maps = try std.ArrayList(Map).initCapacity(alloc, 20);
    defer {
        for (maps.items) |*map| {
            map.deinit();
        }
        maps.deinit();
    }

    while (lines.peek() != null) {
        var map = try Map.init(alloc);
        try map.parseRanges(&lines);
        try maps.append(map);
    }

    // Part One
    var lowestSeedLocation: i64 = std.math.maxInt(i64);
    var seedsIter = std.mem.tokenizeScalar(u8, seedsLine[(std.mem.indexOfScalar(u8, seedsLine, ':').? + 1)..], ' ');
    while (seedsIter.next()) |seedText| {
        const seedNum = processSeed(try std.fmt.parseInt(i64, seedText, 10), &maps);
        if (seedNum < lowestSeedLocation) {
            lowestSeedLocation = seedNum;
        }
    }
    std.debug.print("Part One: {d}\n", .{lowestSeedLocation});

    // Part Two
    lowestSeedLocation = std.math.maxInt(i64);
    seedsIter.reset();
    while (seedsIter.next()) |seedText| {
        const seedStart = try std.fmt.parseInt(usize, seedText, 10);
        const seedRange = try std.fmt.parseInt(usize, seedsIter.next().?, 10);

        const lowestInRange = findLowestInRange(seedStart, seedRange, 100_000, &maps);
        if (lowestInRange < lowestSeedLocation) {
            lowestSeedLocation = lowestInRange;
        }
    }
    std.debug.print("Part Two: {d}\n", .{lowestSeedLocation});
}

fn findLowestInRange(start: usize, length: usize, stride: usize, maps: *std.ArrayList(Map)) i64 {
    var lowest: i64 = std.math.maxInt(i64);
    var lowestIndex: usize = 0;
    var i = start;
    const end = start + length;
    while (i < end) : (i += stride) {
        const processedSeed = processSeed(@intCast(i), maps);
        if (processedSeed < lowest) {
            lowest = processedSeed;
            lowestIndex = i;
        }
    }

    if (stride == 1) {
        return lowest;
    }

    const newStart = lowestIndex - stride;
    const newLength = stride * 2;
    return findLowestInRange(newStart, newLength, stride / 10, maps);
}

fn processSeed(seedNum: i64, maps: *std.ArrayList(Map)) i64 {
    var result = seedNum;
    for (maps.*.items) |*map| {
        result = map.processSeed(result);
    }
    return result;
}

const MapRange = struct {
    destStart: i64,
    sourceStart: i64,
    length: i64,

    pub fn parseRange(line: []const u8) !MapRange {
        var iter = std.mem.tokenizeScalar(u8, line, ' ');
        var range = MapRange{
            .destStart = try std.fmt.parseInt(i64, iter.next().?, 10),
            .sourceStart = try std.fmt.parseInt(i64, iter.next().?, 10),
            .length = try std.fmt.parseInt(i64, iter.next().?, 10),
        };
        return range;
    }
};

const Map = struct {
    header: []const u8 = "",
    ranges: std.ArrayList(MapRange),

    pub fn init(allocator: std.mem.Allocator) !Map {
        return Map{
            .header = "",
            .ranges = try std.ArrayList(MapRange).initCapacity(allocator, 20),
        };
    }

    pub fn deinit(self: *Map) void {
        self.ranges.deinit();
    }

    pub fn parseRanges(self: *Map, lines: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar)) !void {
        self.header = lines.next().?;

        var line = lines.next();
        while (line != null and line.?.len > 0) : (line = lines.next()) {
            try self.ranges.append(try MapRange.parseRange(line.?));
        }
    }

    pub fn processSeed(self: *Map, seedNumber: i64) i64 {
        for (self.ranges.items) |range| {
            const offset = seedNumber - range.sourceStart;
            if (offset >= 0 and offset <= range.length - 1) {
                return range.destStart + offset;
            }
        }
        return seedNumber;
    }
};
