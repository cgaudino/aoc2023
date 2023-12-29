const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    const partOne = try minimizeHeatLoss(input, 1, 3, allocator);
    std.debug.print("Part One: {d}\n", .{partOne});

    const partTwo = try minimizeHeatLoss(input, 4, 10, allocator);
    std.debug.print("Part Two: {d}\n", .{partTwo});
}

fn minimizeHeatLoss(input: []const u8, minLineLength: usize, maxLineLength: usize, allocator: std.mem.Allocator) !usize {
    const gridWidth = std.mem.indexOfScalar(u8, input, '\n').?;
    const gridSize = Vec2{ @intCast(gridWidth), @intCast(@divExact(input.len, gridWidth + 1)) };

    const goalPos = gridSize + left + up;
    const startPos = zero;

    var dist = std.AutoHashMap(Node, usize).init(allocator);
    defer dist.deinit();

    var from = std.AutoHashMap(Node, Node).init(allocator);
    defer from.deinit();

    var openSet = std.PriorityQueue(Node, *std.AutoHashMap(Node, usize), orderNode).init(allocator, &dist);
    defer openSet.deinit();

    const startA = .{ .pos = startPos, .dir = null, .lineLength = 0 };
    try dist.put(startA, 0);
    try openSet.add(startA);

    while (openSet.count() > 0) {
        const node = openSet.remove();
        if (@reduce(.And, node.pos == goalPos)) {
            if (node.lineLength < minLineLength) {
                continue;
            }
            return dist.get(node).?;
        }
        const posDist = dist.get(node).?;
        for (directions) |direction| {
            if (@reduce(.And, -direction == (node.dir orelse zero))) {
                continue;
            }
            const neighbor = Node{
                .pos = node.pos + direction,
                .dir = direction,
                .lineLength = if (@reduce(.And, direction == (node.dir orelse zero))) node.lineLength + 1 else 1,
            };
            if (neighbor.lineLength > maxLineLength) {
                continue;
            }
            if (@reduce(.Or, direction != (node.dir orelse direction)) and node.lineLength < minLineLength) {
                continue;
            }
            const neighborIndex = posToIndex(neighbor.pos, gridSize) orelse continue;
            const newDist = posDist + (input[neighborIndex] - '0');
            if (newDist < (dist.get(neighbor) orelse std.math.maxInt(usize))) {
                try dist.put(neighbor, newDist);
                try from.put(neighbor, node);
                try openSet.add(neighbor);
            }
        }
    }
    unreachable;
}

const Vec2 = @Vector(2, isize);

const zero = Vec2{ 0, 0 };
const up = Vec2{ 0, -1 };
const down = Vec2{ 0, 1 };
const left = Vec2{ -1, 0 };
const right = Vec2{ 1, 0 };

const directions = [4]Vec2{ right, left, down, up };

const Node = struct {
    pos: Vec2,
    dir: ?Vec2,
    lineLength: usize = 0,
};

fn posToIndex(pos: Vec2, size: Vec2) ?usize {
    if (@reduce(.Or, pos < zero) or @reduce(.Or, pos >= size)) {
        return null;
    }
    return @intCast((pos[1] * (size[0] + 1)) + pos[0]);
}

fn orderNode(context: *std.AutoHashMap(Node, usize), a: Node, b: Node) std.math.Order {
    const aVal = context.get(a) orelse std.math.maxInt(usize);
    const bVal = context.get(b) orelse std.math.maxInt(usize);
    return std.math.order(aVal, bVal);
}

fn countRepeatedDirs(curr: Node, from: *std.AutoHashMap(Node, Node)) usize {
    var result: usize = 0;
    var c = curr;
    var dir = c.dir orelse zero;
    while (true) {
        if (@reduce(.Or, (c.dir orelse zero) != dir)) {
            break;
        }
        c = from.get(c) orelse break;
        result += 1;
    }
    return result;
}
