const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var nodeCache = std.StringArrayHashMap(Node).init(alloc);
    defer nodeCache.deinit();

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');

    const directions = lineIter.next().?;

    while (lineIter.next()) |line| {
        var nodeDataIter = std.mem.tokenizeAny(u8, line, "=(,) ");

        const nodeName = nodeDataIter.next().?;
        const leftChildName = nodeDataIter.next().?;
        const rightChildName = nodeDataIter.next().?;

        try nodeCache.put(nodeName, Node{
            .name = nodeName,
            .children_names = [2][]const u8{ leftChildName, rightChildName },
        });
    }

    var currentNode: *Node = nodeCache.getPtr("AAA").?;
    var instructionIndex: usize = 0;

    while (!std.mem.eql(u8, currentNode.name, "ZZZ")) : (instructionIndex += 1) {
        const dir: usize = switch (directions[instructionIndex % directions.len]) {
            'L' => 0,
            'R' => 1,
            else => unreachable,
        };

        if (currentNode.children[dir] == null) {
            currentNode.children[dir] = nodeCache.getPtr(currentNode.children_names[dir]).?;
        }
        currentNode = currentNode.children[dir].?;
    }

    std.debug.print("Part One: {d}\n", .{instructionIndex});

    var currentNodes = std.ArrayList(*Node).init(alloc);
    defer currentNodes.deinit();
    var nodeSteps = std.ArrayList(usize).init(alloc);
    defer nodeSteps.deinit();

    for (nodeCache.keys()) |key| {
        if (key[2] == 'A') {
            try currentNodes.append(nodeCache.getPtr(key).?);
            try nodeSteps.append(0);
        }
    }

    instructionIndex = 0;
    var foundNodes: usize = 0;
    while (currentNodes.items.len > 0) : (instructionIndex += 1) {
        const dir: usize = switch (directions[instructionIndex % directions.len]) {
            'L' => 0,
            'R' => 1,
            else => unreachable,
        };

        for (currentNodes.items, 0..) |node, i| {
            if (node.children[dir] == null) {
                node.children[dir] = nodeCache.getPtr(node.children_names[dir]).?;
            }
            currentNodes.items[i] = node.children[dir].?;

            if (nodeSteps.items[i] == 0 and currentNodes.items[i].name[2] == 'Z') {
                nodeSteps.items[i] = instructionIndex + 1;
                foundNodes += 1;
            }
        }

        if (foundNodes == currentNodes.items.len) {
            break;
        }
    }

    std.debug.print("Part Two: {d}\n", .{leastCommonMultipleSlice(usize, nodeSteps.items)});
}

const Node = struct {
    name: []const u8,

    children: [2]?*Node = .{ null, null },
    children_names: [2][]const u8,
};

fn greatestCommonFactor(comptime T: type, a: T, b: T) T {
    var _a = a;
    var _b = b;
    while (_b != 0) {
        var temp = _b;
        _b = _a % _b;
        _a = temp;
    }
    return _a;
}

fn leastCommonMultiple(comptime T: type, a: T, b: T) T {
    return (a / greatestCommonFactor(T, a, b)) * b;
}

fn leastCommonMultipleSlice(comptime T: type, items: []T) T {
    var result: T = 1;
    for (items) |item| {
        result = leastCommonMultiple(T, result, item);
    }
    return result;
}
