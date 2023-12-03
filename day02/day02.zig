const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const alloc = std.heap.page_allocator;

    const input = try file.readToEndAlloc(alloc, 16000);
    defer alloc.free(input);

    var availableBlocks = std.StringHashMap(u8).init(alloc);
    defer availableBlocks.clearAndFree();
    try availableBlocks.put("red", 12);
    try availableBlocks.put("green", 13);
    try availableBlocks.put("blue", 14);

    var colorCounts = std.StringHashMap(u8).init(alloc);
    defer colorCounts.clearAndFree();

    var partOneCounter: u32 = 0;

    var linesIter = std.mem.tokenizeAny(u8, input, "\n");
    lines_loop: while (linesIter.next()) |line| {
        var sectionIter = std.mem.tokenizeAny(u8, line, ":");

        const header = sectionIter.next().?;
        const games = sectionIter.next().?;

        var headerIter = std.mem.splitScalar(u8, header, ' ');
        _ = headerIter.next();
        const gameId = try std.fmt.parseInt(u32, headerIter.next().?, 10);

        var gameIter = std.mem.tokenizeAny(u8, games, ";");
        while (gameIter.next()) |game| {
            colorCounts.clearRetainingCapacity();

            var colorIter = std.mem.tokenizeAny(u8, game, ",");
            while (colorIter.next()) |colorGroup| {
                var countIter = std.mem.tokenizeScalar(u8, colorGroup, ' ');

                const count = try std.fmt.parseInt(u8, countIter.next().?, 10);
                const colorText = countIter.next().?;

                var entry = try colorCounts.getOrPut(colorText);
                entry.value_ptr.* = if (entry.found_existing) entry.value_ptr.* + count else count;
            }

            var keyIter = colorCounts.keyIterator();
            while (keyIter.next()) |key| {
                if (colorCounts.get(key.*).? > availableBlocks.get(key.*).?) {
                    continue :lines_loop;
                }
            }
        }

        partOneCounter += gameId;
    }

    std.debug.print("Part One: {d}\n", .{partOneCounter});
}
