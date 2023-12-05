const std = @import("std");

const symbols = "!@#$%^&*+=-/\\";
const nonNumerals = symbols ++ ".";

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    const alloc = std.heap.page_allocator;

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var lines = std.mem.tokenizeAny(u8, input, "\n");

    var sum: u32 = 0;
    var prevLine: ?[]const u8 = null;
    while (lines.next()) |line| {
        var numbersIter = std.mem.tokenizeAny(u8, line, nonNumerals);
        while (numbersIter.next()) |number| {
            const numIndex = numbersIter.index - number.len;
            const numLength = number.len;

            const searchStart = if (numIndex == 0) numIndex else numIndex - 1;
            const searchLength = if (numIndex == 0) numLength + 1 else numLength + 2;

            const hasAdjacentSymbol = containsSymbolBeforeIndex(prevLine, searchStart, searchLength) or
                containsSymbolBeforeIndex(line, searchStart, searchLength) or
                containsSymbolBeforeIndex(lines.peek(), searchStart, searchLength);

            if (hasAdjacentSymbol) {
                const value = std.fmt.parseInt(u32, number, 10);
                sum += value;
            }
        }
        prevLine = line;
    }

    std.debug.print("Part One: {d}\n", .{sum});
}

fn containsSymbolBeforeIndex(slice: ?[]const u8, startIndex: usize, length: usize) bool {
    if (slice == null) {
        return false;
    }

    const symbolIndex = std.mem.indexOfAny(u8, slice.?[startIndex..], symbols);

    return symbolIndex != null and symbolIndex.? < length;
}
