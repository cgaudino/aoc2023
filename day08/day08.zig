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
}

const Node = struct {
    name: []const u8,

    children: [2]?*Node = .{ null, null },
    children_names: [2][]const u8,
};
