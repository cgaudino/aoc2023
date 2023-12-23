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

    const gridSize = Vec2{ lineWidth, @divExact(input.len, lineWidth + 1) };

    const startIndex = std.mem.indexOfScalar(u8, input, 'S').?;
    const startPos = indexToPos(startIndex, gridSize);

    var setA = std.AutoHashMap(Vec2, void).init(allocator);
    defer setA.deinit();

    var setB = std.AutoHashMap(Vec2, void).init(allocator);
    defer setB.deinit();

    try setA.put(startPos, {});

    const numSteps: usize = 64;
    try takeStep(&setA, &setB, gridSize, input, numSteps);

    std.debug.print("Part One: {d}\n", .{@max(setA.count(), setB.count())});
}

const Vec2 = @Vector(2, usize);

const down = Vec2{ 0, 1 };
const right = Vec2{ 1, 0 };

fn posToIndex(pos: Vec2, gridSize: Vec2) usize {
    return pos[1] * (gridSize[0] + 1) + pos[0];
}

fn indexToPos(i: usize, gridSize: Vec2) Vec2 {
    return Vec2{ i % (gridSize[0] + 1), @divFloor(i, (gridSize[0] + 1)) };
}

fn takeStep(setA: *std.AutoHashMap(Vec2, void), setB: *std.AutoHashMap(Vec2, void), gridSize: Vec2, input: []const u8, stepsRemaining: usize) !void {
    if (stepsRemaining == 0) {
        return;
    }
    var keyIter = setA.keyIterator();
    while (keyIter.next()) |key| {
        const pos = key.*;

        if (pos[1] < gridSize[1] - 1) {
            const d = pos + down;
            if (input[posToIndex(d, gridSize)] != '#') {
                try setB.put(d, {});
            }
        }

        if (pos[1] > 0) {
            const u = pos - down;
            if (input[posToIndex(u, gridSize)] != '#') {
                try setB.put(u, {});
            }
        }

        if (pos[0] < gridSize[0] - 1) {
            const r = pos + right;
            if (input[posToIndex(r, gridSize)] != '#') {
                try setB.put(r, {});
            }
        }

        if (pos[0] > 0) {
            const l = pos - right;
            if (input[posToIndex(l, gridSize)] != '#') {
                try setB.put(l, {});
            }
        }
    }

    setA.clearRetainingCapacity();

    try takeStep(setB, setA, gridSize, input, stepsRemaining - 1);
}
