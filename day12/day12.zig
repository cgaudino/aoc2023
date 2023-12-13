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

    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');
    var partOne: u64 = 0;
    while (linesIter.next()) |line| {
        partOne += try processLine(line, &groupsBuffer);
    }
    std.debug.print("Part One: {d}\n", .{partOne});
}

fn processLine(line: []const u8, buffer: []u32) !u64 {
    const separatorIndex = std.mem.indexOfScalar(u8, line, ' ').?;
    const springs = line[0..separatorIndex];

    var groupsIter = std.mem.tokenizeScalar(u8, line[(separatorIndex + 1)..], ',');
    var groupCount: usize = 0;
    while (groupsIter.next()) |group| {
        buffer[groupCount] = try std.fmt.parseInt(u32, group, 10);
        groupCount += 1;
    }

    var groups = buffer[0..groupCount];

    return findValidConfigurations(springs, groups, 0, false, null);
}

fn findValidConfigurations(springs: []const u8, groups: []u32, groupSize: isize, inGroup: bool, replacementChar: ?u8) u64 {
    const char = if (replacementChar != null) replacementChar.? else springs[0];
    switch (char) {
        '.' => {
            var newGroup = groups;
            if (inGroup) {
                if (groupSize != groups[0]) {
                    return 0;
                }
                if (groups.len == 1) {
                    return if (std.mem.indexOfScalar(u8, springs, '#') == null) 1 else 0;
                }
                newGroup = groups[1..];
            }
            if (springs.len == 1) {
                return 0;
            }
            return findValidConfigurations(springs[1..], newGroup, 0, false, null);
        },
        '#' => {
            if (springs.len == 1) {
                return if (groups.len == 1 and groups[0] == groupSize + 1) 1 else 0;
            }
            return findValidConfigurations(springs[1..], groups, groupSize + 1, true, null);
        },
        '?' => {
            return findValidConfigurations(springs, groups, groupSize, inGroup, '.') +
                findValidConfigurations(springs, groups, groupSize, inGroup, '#');
        },
        else => unreachable,
    }
}
