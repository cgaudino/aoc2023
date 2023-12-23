const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var modules = std.StringHashMap(Module).init(allocator);
    defer modules.deinit();

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (lineIter.next()) |line| {
        const module = try Module.parse(line);
        try modules.put(module.getName(), module);
    }

    var keysIter = modules.keyIterator();
    while (keysIter.next()) |key| {
        var module = modules.getPtr(key.*).?;
        const destinationCount = module.getDestinationCount();
        for (0..destinationCount) |i| {
            const destinationName = module.getDestinations()[i];
            if (modules.getPtr(destinationName)) |target| {
                target.addInput(module.getName());
            }
        }
    }

    var pulses = PulseQueue.init(allocator);
    defer pulses.deinit();
    for (0..1000) |_| {
        try pulses.addPulse(.{ .high = false, .source = "button", .destination = "broadcaster" });
        while (pulses.len() > 0) {
            const pulse = pulses.popPulse();
            if (modules.getPtr(pulse.destination)) |module| {
                try module.processPulse(pulse, &pulses);
            }
        }
    }

    std.debug.print("Part One: {d}\n", .{pulses.lowPulseCount * pulses.highPulseCount});
}

const Pulse = struct {
    source: []const u8,
    destination: []const u8,
    high: bool,
};

const PulseQueue = struct {
    pulses: std.ArrayList(Pulse),
    lowPulseCount: usize,
    highPulseCount: usize,

    fn init(allocator: std.mem.Allocator) PulseQueue {
        return .{
            .pulses = std.ArrayList(Pulse).init(allocator),
            .lowPulseCount = 0,
            .highPulseCount = 0,
        };
    }

    fn deinit(self: *PulseQueue) void {
        self.pulses.deinit();
    }

    fn addPulse(self: *PulseQueue, pulse: Pulse) !void {
        try self.pulses.insert(0, pulse);
        if (pulse.high) {
            self.highPulseCount += 1;
        } else {
            self.lowPulseCount += 1;
        }
    }

    fn popPulse(self: *PulseQueue) Pulse {
        return self.pulses.pop();
    }

    fn len(self: *const PulseQueue) usize {
        return self.pulses.items.len;
    }
};

const Module = union(enum) {
    flipFlop: FlipFlop,
    broadcaster: Broadcaster,
    conjunction: Conjunction,

    fn parse(text: []const u8) !Module {
        var splitIter = std.mem.splitSequence(u8, text, " -> ");

        const moduleName = splitIter.next().?;
        const destinations = splitIter.next().?;

        const broadcasterName = "broadcaster";
        if (std.mem.eql(u8, moduleName, broadcasterName)) {
            return try Broadcaster.init(moduleName, destinations);
        }
        switch (text[0]) {
            '%' => {
                return try FlipFlop.init(moduleName[1..], destinations);
            },
            '&' => {
                return try Conjunction.init(moduleName[1..], destinations);
            },
            else => unreachable,
        }
    }

    fn processPulse(self: *Module, pulse: Pulse, queue: *PulseQueue) !void {
        return switch (self.*) {
            inline else => |*m| m.processPulse(pulse, queue),
        };
    }

    fn getName(self: *const Module) []const u8 {
        return switch (self.*) {
            inline else => |m| m.name,
        };
    }

    fn getDestinations(self: *const Module) []const []const u8 {
        return switch (self.*) {
            inline else => |m| m.destinationNames[0..m.destinationCount],
        };
    }

    fn getDestinationCount(self: *const Module) usize {
        return switch (self.*) {
            inline else => |m| m.destinationCount,
        };
    }

    fn addInput(self: *Module, input: []const u8) void {
        return switch (self.*) {
            .conjunction => |*c| c.addInput(input),
            inline else => {},
        };
    }

    fn parseDestinations(destinations: []const u8, array: [*][]const u8, count: *usize) void {
        var iter = std.mem.tokenizeAny(u8, destinations, " ,");
        while (iter.next()) |destination| {
            array[count.*] = destination;
            count.* += 1;
        }
    }
};

const Broadcaster = struct {
    name: []const u8,
    destinationNames: [10][]const u8 = undefined,
    destinationCount: usize = 0,

    fn init(name: []const u8, destinations: []const u8) !Module {
        var broadcaster = Broadcaster{ .name = name };
        Module.parseDestinations(destinations, &broadcaster.destinationNames, &broadcaster.destinationCount);
        return .{ .broadcaster = broadcaster };
    }

    fn processPulse(self: *const Broadcaster, pulse: Pulse, queue: *PulseQueue) !void {
        for (0..self.destinationCount) |i| {
            try queue.addPulse(.{
                .high = pulse.high,
                .source = self.name,
                .destination = self.destinationNames[i],
            });
        }
    }
};

const FlipFlop = struct {
    name: []const u8,
    destinationNames: [10][]const u8 = undefined,
    destinationCount: usize = 0,
    state: bool = false,

    fn init(name: []const u8, destinations: []const u8) !Module {
        var flipflop = FlipFlop{ .name = name };
        Module.parseDestinations(destinations, &flipflop.destinationNames, &flipflop.destinationCount);
        return .{ .flipFlop = flipflop };
    }

    fn processPulse(self: *FlipFlop, pulse: Pulse, queue: *PulseQueue) !void {
        if (pulse.high) {
            return;
        }

        self.state = !self.state;
        for (0..self.destinationCount) |i| {
            try queue.addPulse(.{
                .high = self.state,
                .source = self.name,
                .destination = self.destinationNames[i],
            });
        }
    }
};

const Conjunction = struct {
    name: []const u8,
    destinationNames: [10][]const u8 = undefined,
    destinationCount: usize = 0,
    inputNames: [10][]const u8 = undefined,
    inputState: [10]bool = [1]bool{false} ** 10,
    inputCount: usize = 0,

    fn init(name: []const u8, destinations: []const u8) !Module {
        var conjunction = Conjunction{ .name = name };
        Module.parseDestinations(destinations, &conjunction.destinationNames, &conjunction.destinationCount);
        return .{ .conjunction = conjunction };
    }

    fn processPulse(self: *Conjunction, pulse: Pulse, queue: *PulseQueue) !void {
        var allHigh: bool = true;
        for (0..self.inputCount) |i| {
            if (std.mem.eql(u8, pulse.source, self.inputNames[i])) {
                self.inputState[i] = pulse.high;
            }
            allHigh = allHigh and self.inputState[i];
        }
        for (0..self.destinationCount) |i| {
            try queue.addPulse(.{
                .high = !allHigh,
                .source = self.name,
                .destination = self.destinationNames[i],
            });
        }
    }

    fn addInput(self: *Conjunction, input: []const u8) void {
        for (0..self.inputCount) |i| {
            if (std.mem.eql(u8, self.inputNames[i], input)) {
                return;
            }
        }
        self.inputNames[self.inputCount] = input;
        self.inputState[self.inputCount] = false;
        self.inputCount += 1;
    }
};
