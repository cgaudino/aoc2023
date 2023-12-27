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

    const longestPath = try findLongestPath(input, gridSize, startPos, &visited, 0, 0);

    std.debug.print("Part One: {d}\n", .{longestPath});
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

fn findLongestPath(grid: []const u8, gridSize: Vec2, pos: Vec2, visited: *std.AutoHashMap(Vec2, void), currentLength: usize, maxLength: usize) !usize {
    try visited.put(pos, {});

    var buffer: [4]Vec2 = [_]Vec2{.{ 0, 0 }} ** 4;

    var newMaxLength = maxLength;

    if (getTraversableNeighbors(pos, grid, gridSize, &buffer)) |neighbors| {
        for (neighbors) |neighbor| {
            if (visited.contains(neighbor)) {
                continue;
            }
            const result = try findLongestPath(grid, gridSize, neighbor, visited, currentLength + 1, @max(currentLength + 1, maxLength));
            newMaxLength = @max(result, newMaxLength);
        }
    }
    _ = visited.remove(pos);
    return newMaxLength;
}

fn getTraversableNeighbors(pos: Vec2, grid: []const u8, gridSize: Vec2, buffer: *[4]Vec2) ?[]Vec2 {
    const up = Vec2{ 0, -1 };
    const down = Vec2{ 0, 1 };
    const left = Vec2{ -1, 0 };
    const right = Vec2{ 1, 0 };
    const directions = [_]Vec2{ up, down, left, right };

    var curIndex = posToIndex(pos, gridSize) orelse return null;

    switch (grid[curIndex]) {
        '>' => {
            buffer[0] = pos + right;
            return buffer[0..1];
        },
        '<' => {
            buffer[0] = pos + left;
            return buffer[0..1];
        },
        'v' => {
            buffer[0] = pos + down;
            return buffer[0..1];
        },
        '^' => {
            buffer[0] = pos + up;
            return buffer[0..1];
        },
        '.' => {
            var i: usize = 0;
            for (directions) |direction| {
                const neighbor = pos + direction;
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
