const std = @import("std");

const symbols = "!@#$%^&*+=-/\\";
const nonNumerals = symbols ++ ".";

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var lines = std.mem.tokenizeAny(u8, input, "\n");

    var partNumberSum: u32 = 0;
    var gearRatioSum: u64 = 0;
    var prevLine: ?[]const u8 = null;
    while (lines.next()) |line| {
        // Search for part numbers
        var numbersIter = std.mem.tokenizeAny(u8, line, nonNumerals);
        while (numbersIter.next()) |number| {
            const numIndex = numbersIter.index - number.len;
            const numLength = number.len;

            const searchStart = if (numIndex == 0) numIndex else numIndex - 1;
            const searchLength = if (numIndex == 0) numLength + 1 else numLength + 2;

            const hasAdjacentSymbol = containsAdjacentSymbol(prevLine, searchStart, searchLength) or
                containsAdjacentSymbol(line, searchStart, searchLength) or
                containsAdjacentSymbol(lines.peek(), searchStart, searchLength);

            if (hasAdjacentSymbol) {
                const value = try std.fmt.parseInt(u32, number, 10);
                partNumberSum += value;
            }
        }

        // Search for gears
        for (line, 0..) |char, i| {
            if (char != '*') {
                continue;
            }

            var gearRatio: u64 = 1;
            var numRatios: u64 = 0;

            try searchForGearRatios(prevLine, i, &gearRatio, &numRatios);
            try searchForGearRatios(line, i, &gearRatio, &numRatios);
            try searchForGearRatios(lines.peek(), i, &gearRatio, &numRatios);

            if (numRatios == 2) {
                gearRatioSum += gearRatio;
            }
        }

        prevLine = line;
    }

    std.debug.print("Part One: {d}\n", .{partNumberSum});
    std.debug.print("Part Two: {d}\n", .{gearRatioSum});
}

fn containsAdjacentSymbol(slice: ?[]const u8, startIndex: usize, length: usize) bool {
    if (slice == null) {
        return false;
    }

    const symbolIndex = std.mem.indexOfAny(u8, slice.?[startIndex..], symbols);

    return symbolIndex != null and symbolIndex.? < length;
}

fn searchForGearRatios(line: ?[]const u8, gearIndex: usize, gearRatio: *u64, numRatios: *u64) !void {
    if (line == null) {
        return;
    }

    var numIter = std.mem.tokenizeAny(u8, line.?, nonNumerals);
    while (numIter.next()) |number| {
        var numStartIndex = numIter.index - number.len;
        const numEndIndex = numIter.index;

        if (numStartIndex > 0) {
            numStartIndex -= 1;
        }

        if (gearIndex >= numStartIndex and gearIndex <= numEndIndex) {
            numRatios.* += 1;
            gearRatio.* *= try std.fmt.parseInt(u32, number, 10);
        }
    }
}
