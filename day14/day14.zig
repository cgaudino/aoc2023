const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    var reader = file.reader();

    var stateCache = std.AutoHashMap(u64, usize).init(alloc);
    defer stateCache.deinit();

    var rows = std.ArrayList([]u8).init(alloc);
    defer {
        for (rows.items) |row| {
            alloc.free(row);
        }
        rows.deinit();
    }

    while (try reader.readUntilDelimiterOrEofAlloc(alloc, '\n', 2048)) |row| {
        try rows.append(row);
    }

    shiftNorth(rows.items);
    std.debug.print("Part One: {d}\n", .{calculateLoad(rows.items)});
    shiftWest(rows.items);
    shiftSouth(rows.items);
    shiftEast(rows.items);

    const iterations: usize = 1_000_000_000;
    var i: usize = 1;
    while (i < iterations) : (i += 1) {
        shiftNorth(rows.items);
        shiftWest(rows.items);
        shiftSouth(rows.items);
        shiftEast(rows.items);

        if (try checkForPreviousOccurence(rows.items, &stateCache, i)) |prevIndex| {
            const cycleLength = i - prevIndex;
            i += cycleLength * ((iterations - i) / cycleLength);
        }
    }
    std.debug.print("Part Two: {d}\n", .{calculateLoad(rows.items)});
}

fn checkForPreviousOccurence(rows: [][]u8, cache: *std.AutoHashMap(u64, usize), index: usize) !?usize {
    var hash: u64 = 0;
    for (rows) |row| {
        hash += std.hash_map.hashString(row);
    }
    if (try cache.fetchPut(hash, index)) |kv| {
        return kv.value;
    }
    return null;
}

fn printRows(rows: [][]u8) void {
    for (rows) |row| {
        std.debug.print("{s}\n", .{row});
    }
    std.debug.print("\n", .{});
}

fn shiftNorth(rows: [][]u8) void {
    for (rows, 0..) |row, i| {
        for (row, 0..) |char, c| {
            if (char != 'O') {
                continue;
            }
            var jump: usize = 0;
            while (i >= jump + 1) : (jump += 1) {
                if (rows[i - jump - 1][c] != '.') {
                    break;
                }
            }
            if (jump > 0) {
                rows[i - jump][c] = rows[i][c];
                rows[i][c] = '.';
            }
        }
    }
}

fn shiftSouth(rows: [][]u8) void {
    var i = rows.len;
    while (i > 0) {
        i -= 1;
        const row = rows[i];
        for (row, 0..) |char, c| {
            if (char != 'O') {
                continue;
            }
            var jump: usize = 0;
            while (rows.len > i + jump + 1) : (jump += 1) {
                if (rows[i + jump + 1][c] != '.') {
                    break;
                }
            }
            if (jump > 0) {
                rows[i + jump][c] = rows[i][c];
                rows[i][c] = '.';
            }
        }
    }
}

fn shiftEast(rows: [][]u8) void {
    for (rows, 0..) |_, r| {
        var row = rows[r];
        var i = row.len;
        while (i > 0) {
            i -= 1;
            if (row[i] != 'O') {
                continue;
            }
            var jump: usize = 0;
            while (row.len > i + jump + 1) : (jump += 1) {
                if (row[i + jump + 1] != '.') {
                    break;
                }
            }
            if (jump > 0) {
                row[i + jump] = row[i];
                row[i] = '.';
            }
        }
    }
}

fn shiftWest(rows: [][]u8) void {
    for (rows, 0..) |_, r| {
        var row = rows[r];
        for (row, 0..) |char, i| {
            if (char != 'O') {
                continue;
            }
            var jump: usize = 0;
            while (i >= jump + 1) : (jump += 1) {
                if (row[i - jump - 1] != '.') {
                    break;
                }
            }
            if (jump > 0) {
                row[i - jump] = char;
                row[i] = '.';
            }
        }
    }
}

fn calculateLoad(rows: [][]u8) usize {
    var load: usize = 0;
    for (rows, 0..) |row, i| {
        load += std.mem.count(u8, row, "O") * (rows.len - i);
    }
    return load;
}
