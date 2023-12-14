const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var rows = std.ArrayList([]const u8).init(alloc);
    defer rows.deinit();

    var linesIter = std.mem.splitScalar(u8, input, '\n');
    var partOne: usize = 0;
    while (linesIter.next()) |line| {
        if (line.len == 0) {
            partOne += findVerticalReflectionLine(rows.items);
            partOne += findHorizontalReflectionLine(rows.items) * 100;
            rows.clearRetainingCapacity();
            continue;
        }
        try rows.append(line);
    }

    std.debug.print("Part One: {d}\n", .{partOne});
}

fn findVerticalReflectionLine(rows: [][]const u8) usize {
    var result = rows[0].len - 1;
    outer: while (result > 0) : (result -= 1) {
        var i: usize = 0;
        while (result >= i + 1 and result + i < rows[0].len) : (i += 1) {
            for (rows) |row| {
                if (row[result - 1 - i] != row[result + i]) {
                    continue :outer;
                }
            }
        }
        return result;
    }
    return 0;
}

fn findHorizontalReflectionLine(rows: [][]const u8) usize {
    var result = rows.len - 1;
    outer: while (result > 0) : (result -= 1) {
        var i: usize = 0;
        while (result >= i + 1 and result + i < rows.len) : (i += 1) {
            if (!std.mem.eql(u8, rows[result - 1 - i], rows[result + i])) {
                continue :outer;
            }
        }
        return result;
    }
    return 0;
}
