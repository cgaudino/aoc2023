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

    const startIndex = std.mem.indexOfScalar(u8, input, 'S').?;
    const startPos = indexToPos(startIndex, gridSize);

    var setA = std.AutoHashMap(Vec2, void).init(allocator);
    defer setA.deinit();

    var setB = std.AutoHashMap(Vec2, void).init(allocator);
    defer setB.deinit();

    var aPtr = &setA;
    var bPtr = &setB;

    try setA.put(startPos, {});
    for (0..64) |_| {
        try takeStep(aPtr, bPtr, gridSize, input, false);

        var temp = aPtr;
        aPtr = bPtr;
        bPtr = temp;
    }
    std.debug.print("Part One: {d}\n", .{@max(setA.count(), setB.count())});

    setA.clearRetainingCapacity();
    setB.clearRetainingCapacity();

    var states = std.ArrayList(Vec2).init(allocator);
    defer states.deinit();

    try setA.put(startPos, {});
    var i: usize = 1;
    const numSteps: usize = 65 + 131 * 3;
    while (i < numSteps) : (i += 1) {
        try takeStep(aPtr, bPtr, gridSize, input, true);

        var temp = aPtr;
        aPtr = bPtr;
        bPtr = temp;

        if (i >= 65 and (i - 65) % 131 == 0) {
            try states.append(Vec2{ @intCast(states.items.len), @max(setA.count(), setB.count()) });
        }
    }

    var quadratic = quadraticFit(states.items);
    var x: isize = 202300;
    var partTwo = quadratic[0] * x * x + quadratic[1] * x + quadratic[2];
    std.debug.print("{d}\n", .{partTwo});
}

const Vec2 = @Vector(2, isize);

const up = Vec2{ 0, -1 };
const down = Vec2{ 0, 1 };
const left = Vec2{ -1, 0 };
const right = Vec2{ 1, 0 };
const directions = [_]Vec2{ up, down, left, right };

fn posToIndex(pos: Vec2, gridSize: Vec2, wrap: bool) ?usize {
    var wrappedPos = pos;
    if (pos[0] < 0 or pos[1] < 0 or pos[0] >= gridSize[0] or pos[1] >= gridSize[1]) {
        if (!wrap) {
            return null;
        }
        wrappedPos = @mod(pos, gridSize);
    }
    return @intCast(wrappedPos[1] * (gridSize[0] + 1) + wrappedPos[0]);
}

fn indexToPos(i: usize, gridSize: Vec2) Vec2 {
    const signedIndex: isize = @intCast(i);
    return Vec2{ @mod(signedIndex, (gridSize[0] + 1)), @divFloor(signedIndex, (gridSize[0] + 1)) };
}

fn takeStep(setA: *std.AutoHashMap(Vec2, void), setB: *std.AutoHashMap(Vec2, void), gridSize: Vec2, input: []const u8, wrap: bool) !void {
    var keyIter = setA.keyIterator();
    while (keyIter.next()) |key| {
        const pos = key.*;

        for (directions) |direction| {
            const newPos = pos + direction;
            if (posToIndex(newPos, gridSize, wrap)) |index| {
                if (input[index] != '#') {
                    try setB.put(newPos, {});
                }
            }
        }
    }

    setA.clearRetainingCapacity();
}

fn quadraticFit(points: []Vec2) [3]isize {
    var matrix: [3][3]f64 = undefined;
    matrix[0] = .{ @floatFromInt(points[0][0] * points[0][0]), @floatFromInt(points[0][0]), 1.0 };
    matrix[1] = .{ @floatFromInt(points[1][0] * points[1][0]), @floatFromInt(points[1][0]), 1.0 };
    matrix[2] = .{ @floatFromInt(points[2][0] * points[2][0]), @floatFromInt(points[2][0]), 1.0 };

    const invertedMatrix = inverseMatrix(matrix);

    var coefficients: [3]isize = undefined;
    coefficients[0] = @intFromFloat(invertedMatrix[0][0] * @as(f64, @floatFromInt(points[0][1])) + invertedMatrix[0][1] * @as(f64, @floatFromInt(points[1][1])) + invertedMatrix[0][2] * @as(f64, @floatFromInt(points[2][1])));
    coefficients[1] = @intFromFloat(invertedMatrix[1][0] * @as(f64, @floatFromInt(points[0][1])) + invertedMatrix[1][1] * @as(f64, @floatFromInt(points[1][1])) + invertedMatrix[1][2] * @as(f64, @floatFromInt(points[2][1])));
    coefficients[2] = @intFromFloat(invertedMatrix[2][0] * @as(f64, @floatFromInt(points[0][1])) + invertedMatrix[2][1] * @as(f64, @floatFromInt(points[1][1])) + invertedMatrix[2][2] * @as(f64, @floatFromInt(points[2][1])));

    return coefficients;
}

fn inverseMatrix(matrix: [3][3]f64) [3][3]f64 {
    const determinant =
        matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1]) -
        matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0]) +
        matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0]);

    const reciprocalDeterminant = 1.0 / determinant;

    var result: [3][3]f64 = undefined;

    result[0][0] = (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1]) * reciprocalDeterminant;
    result[0][1] = (matrix[0][2] * matrix[2][1] - matrix[0][1] * matrix[2][2]) * reciprocalDeterminant;
    result[0][2] = (matrix[0][1] * matrix[1][2] - matrix[0][2] * matrix[1][1]) * reciprocalDeterminant;

    result[1][0] = (matrix[1][2] * matrix[2][0] - matrix[1][0] * matrix[2][2]) * reciprocalDeterminant;
    result[1][1] = (matrix[0][0] * matrix[2][2] - matrix[0][2] * matrix[2][0]) * reciprocalDeterminant;
    result[1][2] = (matrix[0][2] * matrix[1][0] - matrix[0][0] * matrix[1][2]) * reciprocalDeterminant;

    result[2][0] = (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0]) * reciprocalDeterminant;
    result[2][1] = (matrix[0][1] * matrix[2][0] - matrix[0][0] * matrix[2][1]) * reciprocalDeterminant;
    result[2][2] = (matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]) * reciprocalDeterminant;

    return result;
}
