const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var groupsBuffer: [32]u32 = .{1} ** 32;
    var unfoldBuffer: []u8 = try alloc.alloc(u8, 2048);
    defer alloc.free(unfoldBuffer);
    var cache = std.AutoHashMap(Query, u64).init(alloc);
    defer cache.deinit();

    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');
    var partOne: u64 = 0;
    var partTwo: u64 = 0;
    while (linesIter.next()) |line| {
        cache.clearRetainingCapacity();
        partOne += try processLine(line, unfoldBuffer, &groupsBuffer, &cache, 1);
        cache.clearRetainingCapacity();
        partTwo += try processLine(line, unfoldBuffer, &groupsBuffer, &cache, 5);
    }
    std.debug.print("Part One: {d}\nPart Two: {d}\n", .{ partOne, partTwo });
}

fn processLine(line: []const u8, unfoldBuffer: []u8, buffer: []u32, cache: *std.AutoHashMap(Query, u64), foldCount: usize) !u64 {
    const separatorIndex = std.mem.indexOfScalar(u8, line, ' ').?;
    const springs = unfold(u8, line[0..separatorIndex], unfoldBuffer, '?', foldCount);

    var groupsIter = std.mem.tokenizeScalar(u8, line[(separatorIndex + 1)..], ',');
    var groupCount: usize = 0;
    while (groupsIter.next()) |group| {
        buffer[groupCount] = try std.fmt.parseInt(u32, group, 10);
        groupCount += 1;
    }

    var groups = unfold(u32, buffer[0..groupCount], buffer, null, foldCount);

    const query = .{ .springIndex = 0, .groupIndex = 0, .groupSize = 0, .inGroup = false, .replacementChar = null };
    const result = findValidConfigurations(query, springs, groups, cache);

    return result;
}

fn unfold(comptime T: type, source: []const T, buffer: []T, separator: ?T, count: usize) []T {
    if (source.ptr != buffer.ptr) {
        @memcpy(buffer[0..source.len], source);
    }

    var i: usize = 1;
    var copyDestIndex = source.len;
    while (i < count) : (i += 1) {
        if (separator) |s| {
            buffer[copyDestIndex] = s;
            copyDestIndex += 1;
        }
        @memcpy(buffer[copyDestIndex .. copyDestIndex + source.len], source);
        copyDestIndex += source.len;
    }
    return buffer[0..copyDestIndex];
}

fn findValidConfigurations(query: Query, springs: []const u8, groups: []u32, cache: *std.AutoHashMap(Query, u64)) u64 {
    if (cache.get(query)) |result| {
        return result;
    }

    const char = if (query.replacementChar != null) query.replacementChar.? else springs[query.springIndex];
    switch (char) {
        '.' => {
            var newGroupIndex = query.groupIndex;
            if (query.inGroup) {
                if (query.groupSize != groups[query.groupIndex]) {
                    return 0;
                }
                if (query.isLastGroup(groups)) {
                    return if (std.mem.indexOfScalar(u8, springs[query.springIndex..], '#') == null) 1 else 0;
                }
                newGroupIndex += 1;
            }
            if (query.isLastSpring(springs)) {
                return 0;
            }
            const result = findValidConfigurations(query.next(newGroupIndex, 0, false), springs, groups, cache);
            cache.put(query, result) catch {};
            return result;
        },
        '#' => {
            if (query.isLastSpring(springs)) {
                return if (query.isLastGroup(groups) and groups[query.groupIndex] == query.groupSize + 1) 1 else 0;
            }
            const result = findValidConfigurations(query.next(query.groupIndex, query.groupSize + 1, true), springs, groups, cache);
            cache.put(query, result) catch {};
            return result;
        },
        '?' => {
            return findValidConfigurations(query.replaceChar('.'), springs, groups, cache) +
                findValidConfigurations(query.replaceChar('#'), springs, groups, cache);
        },
        else => unreachable,
    }
}

const Query = struct {
    springIndex: usize,
    groupIndex: usize,
    groupSize: isize,
    inGroup: bool,
    replacementChar: ?u8,

    fn next(self: Query, groupIndex: usize, groupSize: isize, inGroup: bool) Query {
        return .{
            .springIndex = self.springIndex + 1,
            .groupIndex = groupIndex,
            .groupSize = groupSize,
            .inGroup = inGroup,
            .replacementChar = null,
        };
    }

    fn replaceChar(self: Query, char: u8) Query {
        return .{
            .springIndex = self.springIndex,
            .groupIndex = self.groupIndex,
            .groupSize = self.groupSize,
            .inGroup = self.inGroup,
            .replacementChar = char,
        };
    }

    fn isLastSpring(self: Query, springs: []const u8) bool {
        return self.springIndex == springs.len - 1;
    }

    fn isLastGroup(self: Query, groups: []u32) bool {
        return self.groupIndex == groups.len - 1;
    }
};
