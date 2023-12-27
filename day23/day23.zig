const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    const lineWidth = std.mem.indexOfScalar(u8, input, '\n').?;

    const gridSize = Vec2{ @intCast(lineWidth), @intCast(@divExact(input.len, lineWidth + 1)) };

    var visited = std.AutoHashMap(Vec2, void).init(allocator);
    defer visited.deinit();

    const startIndex = std.mem.indexOfScalar(u8, input, '.').?;
    const startPos = indexToPos(startIndex, gridSize);
    const endIndex = std.mem.lastIndexOfScalar(u8, input, '.').?;
    const endPos = indexToPos(endIndex, gridSize);

    const partOne = try findLongestPath(input, gridSize, startPos, endPos, &visited, 0, false);
    std.debug.print("Part One: {d}\n", .{partOne});

    const partTwo = try findLongestPath(input, gridSize, startPos, endPos, &visited, 0, true);
    std.debug.print("Part Two: {d}\n", .{partTwo});
}

const Vec2 = @Vector(2, isize);

fn posToIndex(pos: Vec2, gridSize: Vec2) ?usize {
    if (pos[0] < 0 or pos[1] < 0 or pos[0] >= gridSize[0] or pos[1] >= gridSize[1]) {
        return null;
    }
    return @intCast(pos[1] * (gridSize[0] + 1) + pos[0]);
}

fn indexToPos(i: usize, gridSize: Vec2) Vec2 {
    const signedIndex: isize = @intCast(i);
    return Vec2{ @mod(signedIndex, (gridSize[0] + 1)), @divFloor(signedIndex, (gridSize[0] + 1)) };
}

fn findLongestPath(
    grid: []const u8,
    gridSize: Vec2,
    pos: Vec2,
    target: Vec2,
    visited: *std.AutoHashMap(Vec2, void),
    currentLength: usize,
    climbSlopes: bool,
) !usize {
    var buffer: [4]Vec2 = [_]Vec2{.{ 0, 0 }} ** 4;
    var maxLength: usize = 0;
    try visited.put(pos, {});
    defer _ = visited.remove(pos);

    if (getTraversableNeighbors(pos, grid, gridSize, &buffer, visited, climbSlopes)) |neighbors| {
        for (neighbors) |neighbor| {
            const result = try findLongestPath(grid, gridSize, neighbor, target, visited, currentLength + 1, climbSlopes);
            maxLength = @max(result, maxLength);
        }
        return maxLength;
    } else if (@reduce(.And, pos == target)) {
        return currentLength;
    }

    return 0;
}

fn getTraversableNeighbors(
    pos: Vec2,
    grid: []const u8,
    gridSize: Vec2,
    buffer: *[4]Vec2,
    visited: *std.AutoHashMap(Vec2, void),
    climbSlopes: bool,
) ?[]Vec2 {
    const up = Vec2{ 0, -1 };
    const down = Vec2{ 0, 1 };
    const left = Vec2{ -1, 0 };
    const right = Vec2{ 1, 0 };
    const directions = [_]Vec2{ down, right, left, up };

    var curIndex = posToIndex(pos, gridSize) orelse return null;

    if (climbSlopes) {
        var i: usize = 0;
        for (directions) |direction| {
            const neighbor = pos + direction;
            if (visited.contains(neighbor)) {
                continue;
            }
            const neighborIndex = posToIndex(neighbor, gridSize) orelse continue;
            if (grid[neighborIndex] != '#') {
                buffer[i] = neighbor;
                i += 1;
            }
        }
        return if (i > 0) buffer[0..i] else null;
    }

    switch (grid[curIndex]) {
        '>' => {
            if (visited.contains(pos + right)) {
                return null;
            }
            buffer[0] = pos + right;
            return buffer[0..1];
        },
        '<' => {
            if (visited.contains(pos + left)) {
                return null;
            }
            buffer[0] = pos + left;
            return buffer[0..1];
        },
        'v' => {
            if (visited.contains(pos + down)) {
                return null;
            }
            buffer[0] = pos + down;
            return buffer[0..1];
        },
        '^' => {
            if (visited.contains(pos + up)) {
                return null;
            }
            buffer[0] = pos + up;
            return buffer[0..1];
        },
        '.' => {
            var i: usize = 0;
            for (directions) |direction| {
                const neighbor = pos + direction;
                if (visited.contains(neighbor)) {
                    continue;
                }
                const neighborIndex = posToIndex(neighbor, gridSize) orelse continue;
                if (grid[neighborIndex] != '#') {
                    buffer[i] = neighbor;
                    i += 1;
                }
            }
            return if (i > 0) buffer[0..i] else null;
        },
        else => unreachable,
    }
}
