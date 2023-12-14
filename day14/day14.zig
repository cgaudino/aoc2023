const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var reader = file.reader();

    var rows = std.ArrayList([]u8).init(alloc);
    defer {
        for (rows.items) |row| {
            alloc.free(row);
        }
        rows.deinit();
    }

    while (try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', 2048)) |row| {
        try rows.append(row);

        const i = rows.items.len - 1;
        for (row, 0..) |char, c| {
            if (char != 'O') {
                continue;
            }
            var jump: usize = 0;
            while (i >= jump + 1) : (jump += 1) {
                if (rows.items[i - jump - 1][c] != '.') {
                    break;
                }
            }
            if (jump > 0) {
                rows.items[i - jump][c] = rows.items[i][c];
                rows.items[i][c] = '.';
            }
        }
    }

    var load: usize = 0;
    for (rows.items, 0..) |row, i| {
        load += std.mem.count(u8, row, "O") * (rows.items.len - i);
    }
    std.debug.print("Part One: {d}\n", .{load});
}
