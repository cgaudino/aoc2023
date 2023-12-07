const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, 16000);
    defer alloc.free(input);

    var availableBlocks = std.StringHashMap(u8).init(alloc);
    defer availableBlocks.clearAndFree();
    try availableBlocks.put("red", 12);
    try availableBlocks.put("green", 13);
    try availableBlocks.put("blue", 14);

    var requiredCounts = std.StringHashMap(u8).init(alloc);
    defer requiredCounts.clearAndFree();

    var partOneCounter: u32 = 0;
    var partTwoCounter: u32 = 0;

    var linesIter = std.mem.tokenizeAny(u8, input, "\n");
    while (linesIter.next()) |line| {
        requiredCounts.clearRetainingCapacity();
        var sectionIter = std.mem.tokenizeAny(u8, line, ":");

        const header = sectionIter.next().?;
        const games = sectionIter.next().?;

        var headerIter = std.mem.splitScalar(u8, header, ' ');
        _ = headerIter.next();
        const gameId = try std.fmt.parseInt(u32, headerIter.next().?, 10);

        var gameIter = std.mem.tokenizeAny(u8, games, ";");
        var gameIsPossible = true;
        while (gameIter.next()) |game| {
            var colorIter = std.mem.tokenizeAny(u8, game, ",");
            while (colorIter.next()) |colorGroup| {
                var countIter = std.mem.tokenizeScalar(u8, colorGroup, ' ');

                const count = try std.fmt.parseInt(u8, countIter.next().?, 10);
                const colorText = countIter.next().?;

                if (count > availableBlocks.get(colorText).?) {
                    gameIsPossible = false;
                }

                var requiredEntry = try requiredCounts.getOrPut(colorText);
                requiredEntry.value_ptr.* = if (requiredEntry.found_existing) @max(requiredEntry.value_ptr.*, count) else count;
            }
        }

        if (gameIsPossible) {
            partOneCounter += gameId;
        }

        var requiredCountsIter = requiredCounts.valueIterator();
        var power: u32 = 1;
        while (requiredCountsIter.next()) |value| {
            power *= value.*;
        }
        partTwoCounter += power;
    }

    std.debug.print("Part One: {d}\n", .{partOneCounter});
    std.debug.print("Part Two: {d}\n", .{partTwoCounter});
}
