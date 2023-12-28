const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var nodes = std.StringHashMap(Node).init(allocator);
    defer {
        var iter = nodes.valueIterator();
        while (iter.next()) |val| {
            val.*.connections.deinit();
        }
        nodes.deinit();
    }
    try nodes.ensureTotalCapacity(1000);

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (lineIter.next()) |line| {
        var nodeIter = std.mem.tokenizeAny(u8, line, ": ");
        var leftNode = getOrCreate(nodeIter.next().?, &nodes);
        while (nodeIter.next()) |rightName| {
            var rightNode = getOrCreate(rightName, &nodes);

            try leftNode.connections.put(rightNode.*.name, {});
            try rightNode.connections.put(leftNode.*.name, {});
        }
    }

    var queue = NodeQueue.init(allocator, {});
    defer queue.deinit();

    var edgeWeights = std.AutoHashMap(Edge, usize).init(allocator);
    defer edgeWeights.deinit();

    var r = std.rand.DefaultPrng.init(2048);
    var random = r.random();
    for (0..100) |_| {
        const from = getRandomNode(&nodes, random);
        var to = getRandomNode(&nodes, random);
        while (std.mem.eql(u8, from, to)) {
            to = getRandomNode(&nodes, random);
        }

        try incrementShortestPathWeights(from, to, &nodes, &queue, &edgeWeights);
    }

    for (0..3) |_| {
        removeHighestEdge(&edgeWeights);
    }

    var connectedSet = std.StringHashMap(void).init(allocator);
    defer connectedSet.deinit();
    try addAllConnected(getRandomNode(&nodes, random), &connectedSet, &nodes);
    const countA = connectedSet.count();
    var otherNode = getRandomNode(&nodes, random);
    while (connectedSet.contains(otherNode)) {
        otherNode = getRandomNode(&nodes, random);
    }
    connectedSet.clearRetainingCapacity();
    try addAllConnected(otherNode, &connectedSet, &nodes);
    const countB = connectedSet.count();

    std.debug.print("Part One: {d}\n", .{countA * countB});
}

fn getRandomNode(nodes: *std.StringHashMap(Node), random: std.rand.Random) []const u8 {
    const index = random.uintLessThanBiased(usize, nodes.count() - 1);
    var iter = nodes.keyIterator();
    var result = iter.next().?;
    for (0..index) |_| {
        result = iter.next().?;
    }
    return result.*;
}

fn removeHighestEdge(weights: *std.AutoHashMap(Edge, usize)) void {
    var keyIter = weights.keyIterator();
    var highestEdgePtr: *Edge = undefined;
    var highestWeight: usize = 0;
    while (keyIter.next()) |key| {
        var weight = weights.get(key.*).?;
        if (weight > highestWeight) {
            highestWeight = weight;
            highestEdgePtr = key;
        }
    }

    _ = highestEdgePtr.*.from.*.connections.remove(highestEdgePtr.to.name);
    _ = highestEdgePtr.*.to.*.connections.remove(highestEdgePtr.from.name);

    _ = weights.remove(highestEdgePtr.*);
}

fn addAllConnected(nodeName: []const u8, set: *std.StringHashMap(void), nodes: *std.StringHashMap(Node)) !void {
    try set.put(nodeName, {});
    const node = nodes.getPtr(nodeName).?;
    var neighborIter = node.connections.keyIterator();
    while (neighborIter.next()) |neighbor| {
        if (!set.contains(neighbor.*)) {
            try addAllConnected(neighbor.*, set, nodes);
        }
    }
}

const NodeQueue = std.PriorityQueue(*Node, void, Node.order);

const Node = struct {
    name: []const u8,
    connections: std.StringHashMap(void),

    distance: usize = 0,
    prev: ?*Node = null,
    weight: usize = 0,

    fn order(_: void, a: *Node, b: *Node) std.math.Order {
        return std.math.order(a.*.distance, b.*.distance);
    }
};

const Edge = struct {
    from: *Node,
    to: *Node,

    fn init(a: *Node, b: *Node) Edge {
        return .{
            .from = @ptrFromInt(@min(@intFromPtr(a), @intFromPtr(b))),
            .to = @ptrFromInt(@max(@intFromPtr(a), @intFromPtr(b))),
        };
    }
};

fn getOrCreate(name: []const u8, nodes: *std.StringHashMap(Node)) *Node {
    var entry = nodes.getOrPutAssumeCapacity(name);
    if (!entry.found_existing) {
        entry.value_ptr.* = .{
            .name = name,
            .connections = std.StringHashMap(void).init(nodes.allocator),
        };
    }
    return entry.value_ptr;
}

fn incrementShortestPathWeights(
    from: []const u8,
    to: []const u8,
    nodes: *std.StringHashMap(Node),
    queue: *NodeQueue,
    weights: *std.AutoHashMap(Edge, usize),
) !void {
    var start = nodes.getPtr(from).?;
    var end = nodes.getPtr(to).?;

    while (queue.count() > 0) {
        _ = queue.remove();
    }

    var nodeIter = nodes.valueIterator();
    while (nodeIter.next()) |node| {
        if (node == start) {
            continue;
        }
        node.*.distance = std.math.maxInt(@TypeOf(node.*.distance));
        node.*.prev = null;
        try queue.add(node);
    }

    start.*.distance = 0;
    start.*.prev = null;
    try queue.add(start);

    while (queue.count() > 0) {
        const node = queue.remove();
        if (node.*.distance == std.math.maxInt(usize)) {
            return;
        }
        if (node == end) {
            break;
        }
        var neighborIter = node.*.connections.keyIterator();
        while (neighborIter.next()) |neighborName| {
            var neighbor = nodes.getPtr(neighborName.*).?;
            const newDist = node.*.distance + 1;
            if (newDist < neighbor.*.distance) {
                neighbor.*.distance = newDist;
                neighbor.*.prev = node;
                try queue.add(neighbor);
            }
        }
    }

    var n: ?*Node = end;
    while (n.?.*.prev) |prev| {
        const edge = Edge.init(n.?, prev);
        var entry = try weights.getOrPutValue(edge, 0);
        entry.value_ptr.* += 1;
        n = prev;
    }
}
