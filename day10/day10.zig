const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    const gridWidth = std.mem.indexOfScalar(u8, input, '\n').? + 1;
    const startPosition = std.mem.indexOfScalar(u8, input, 'S').?;

    var mainLoopTiles = std.AutoHashMap(usize, void).init(alloc);
    defer mainLoopTiles.deinit();
    try mainLoopTiles.put(startPosition, {});

    const firstDir = findFirstMove(startPosition, gridWidth, input);
    var direction = firstDir;
    var position = startPosition;
    var iterations: usize = 0;
    while (position != startPosition or iterations == 0) : (iterations += 1) {
        position = try doMove(position, direction, gridWidth);
        direction = getNewDirection(direction, input[position]);

        try mainLoopTiles.put(position, {});
    }
    std.debug.print("Part One: {d}\n", .{iterations / 2});

    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');
    var scannedTiles: usize = 0;
    var interiorTiles: usize = 0;
    var verticalPipes: usize = 0;
    while (linesIter.next()) |line| {
        verticalPipes = 0;
        for (line, 0..) |tile, i| {
            if (mainLoopTiles.contains(i + scannedTiles)) {
                switch (tile) {
                    '|', 'J', 'L' => {
                        verticalPipes += 1;
                    },
                    'S' => {
                        if (firstDir == .up or firstDir == .down) {
                            verticalPipes += 1;
                        }
                    },
                    else => {},
                }
            } else if (verticalPipes % 2 != 0) {
                interiorTiles += 1;
            }
        }
        scannedTiles += line.len + 1;
    }
    std.debug.print("Part Two: {d}\n", .{interiorTiles});
}

const Direction = enum { up, down, left, right, invalid };
const MoveError = error.InvalidDirection;

fn doMove(position: usize, dir: Direction, gridWidth: usize) !usize {
    const negative = dir == .left or dir == .up;
    const diff = switch (dir) {
        .up, .down => gridWidth,
        .left, .right => 1,
        else => return error.InvalidDirection,
    };
    if (negative and position < diff) {
        return error.InvalidDirection;
    }
    return if (negative) position - diff else position + diff;
}

fn findFirstMove(startPosition: usize, gridWidth: usize, map: []const u8) Direction {
    const candidates = [4]Direction{ .up, .down, .left, .right };

    for (candidates) |candidate| {
        const testPosition = doMove(startPosition, candidate, gridWidth) catch {
            continue;
        };
        if (testPosition >= map.len) {
            continue;
        }
        const dir = getNewDirection(candidate, map[testPosition]);
        if (dir != .invalid) {
            return candidate;
        }
    }

    return .invalid;
}

fn getNewDirection(currentDirection: Direction, tile: u8) Direction {
    return switch (currentDirection) {
        .up => switch (tile) {
            '|' => .up,
            'F' => .right,
            '7' => .left,
            else => .invalid,
        },
        .down => switch (tile) {
            '|' => .down,
            'J' => .left,
            'L' => .right,
            else => .invalid,
        },
        .left => switch (tile) {
            '-' => .left,
            'F' => .down,
            'L' => .up,
            else => .invalid,
        },
        .right => switch (tile) {
            '-' => .right,
            'J' => .up,
            '7' => .down,
            else => .invalid,
        },
        else => .invalid,
    };
}
