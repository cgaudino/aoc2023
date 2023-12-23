const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed: f64 = @floatFromInt(timer.read());
        std.debug.print("Finished in {d}ms\n", .{elapsed / std.time.ns_per_ms});
    }

    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var modules = std.StringHashMap(Module).init(allocator);
    defer modules.deinit();

    // Must preallocate enough space for all modules. If map is allowed to grow, ptrs between
    // modules will be invalidated.
    try modules.ensureTotalCapacity(100);

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (lineIter.next()) |line| {
        try Module.init(line, &modules);
    }

    var keysIter = modules.keyIterator();
    while (keysIter.next()) |key| {
        var module = modules.getPtr(key.*).?;
        try module.connectDestinations(&modules);
    }

    var pulses = try PulseQueue.init(allocator);
    defer pulses.deinit();

    var broadcaster = modules.getPtr("broadcaster").?;
    var counter = modules.getPtr("rx").?;
    var counterInput: *Module = counter.logic.counter.input;
    var counterInputs: *std.SegmentedList(*Module, Module.CONNECTION_LIMIT * 2) = &(counterInput.*.logic.conjunction.inputs);
    while (true) : (buttonPresses += 1) {
        try pulses.addPulse(.{ .high = false, .source = broadcaster, .destination = broadcaster });
        while (pulses.popPulse()) |pulse| {
            try pulse.destination.processPulse(pulse, &pulses);
        }

        if (buttonPresses == 1000) {
            std.debug.print("Part One: {d}\n", .{pulses.lowPulseCount * pulses.highPulseCount});
        }

        var allConditionsMet = buttonPresses > 1000;
        for (0..counterInputs.*.count()) |i| {
            if (counterInputs.*.at(i).*.logic.conjunction.firstHighPress == null) {
                allConditionsMet = false;
            }
        }

        if (allConditionsMet) {
            break;
        }
    }

    var partTwo: usize = 1;
    for (0..counterInputs.*.count()) |i| {
        partTwo *= counterInputs.*.at(i).*.logic.conjunction.firstHighPress.?;
    }
    std.debug.print("Part Two: {d}\n", .{partTwo});
}

var buttonPresses: usize = 1;

const Pulse = struct {
    source: *Module,
    destination: *Module,
    high: bool,
};

const PulseQueue = struct {
    buffer: []Pulse,
    head: usize,
    tail: usize,
    lowPulseCount: usize,
    highPulseCount: usize,
    allocator: std.mem.Allocator,

    const PULSE_LIMIT = 2048;

    fn init(allocator: std.mem.Allocator) !PulseQueue {
        return .{
            .buffer = try allocator.alloc(Pulse, PULSE_LIMIT),
            .head = 0,
            .tail = 0,
            .lowPulseCount = 0,
            .highPulseCount = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *PulseQueue) void {
        self.allocator.free(self.buffer);
    }

    fn addPulse(self: *PulseQueue, pulse: Pulse) !void {
        self.buffer[self.tail] = pulse;
        self.tail = (self.tail + 1) % PULSE_LIMIT;

        if (pulse.high) {
            self.highPulseCount += 1;
        } else {
            self.lowPulseCount += 1;
        }
    }

    fn popPulse(self: *PulseQueue) ?Pulse {
        if (self.head != self.tail) {
            const prevHead = self.head;
            self.head = (self.head + 1) % PULSE_LIMIT;
            return self.buffer[prevHead];
        }
        return null;
    }
};

const Module = struct {
    name: []const u8,
    destinationsText: []const u8,
    destinations: std.SegmentedList(*Module, CONNECTION_LIMIT) = undefined,
    logic: ModuleLogic,

    const CONNECTION_LIMIT = 8;

    fn init(text: []const u8, modules: *std.StringHashMap(Module)) !void {
        var splitIter = std.mem.splitSequence(u8, text, " -> ");

        const moduleName = splitIter.next().?;
        const destinations = splitIter.next().?;

        const logicResult = ModuleLogic.init(moduleName);

        var entry = try modules.getOrPut(logicResult.name);
        entry.value_ptr.* = .{
            .name = logicResult.name,
            .destinationsText = destinations,
            .destinations = .{},
            .logic = logicResult.logic,
        };
    }

    fn processPulse(self: *Module, pulse: Pulse, queue: *PulseQueue) !void {
        if (self.logic.processPulse(pulse)) |high| {
            for (0..self.destinations.count()) |i| {
                try queue.addPulse(.{
                    .high = high,
                    .source = self,
                    .destination = self.destinations.at(i).*,
                });
            }
        }
    }

    fn connectDestinations(self: *Module, modules: *std.StringHashMap(Module)) !void {
        var buf = [0]u8{};
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

        var destinationIter = std.mem.tokenizeAny(u8, self.destinationsText, " ,");
        while (destinationIter.next()) |destinationName| {
            var entry = try modules.getOrPut(destinationName);
            if (!entry.found_existing) {
                entry.value_ptr.* = .{
                    .name = destinationName,
                    .destinationsText = "",
                    .destinations = .{},
                    .logic = .{ .counter = .{ .input = self } },
                };
            }
            var ptr = try self.destinations.addOne(allocator);
            ptr.* = entry.value_ptr;

            try ptr.*.logic.addInput(self.name, modules);
        }
    }
};

const ModuleLogic = union(enum) {
    flipFlop: FlipFlop,
    broadcaster: Broadcaster,
    conjunction: Conjunction,
    counter: Counter,

    fn init(name: []const u8) struct { logic: ModuleLogic, name: []const u8 } {
        const broadcasterName = "broadcaster";
        if (std.mem.eql(u8, name, broadcasterName)) {
            return .{ .logic = .{ .conjunction = .{} }, .name = name };
        }
        switch (name[0]) {
            '%' => {
                return .{ .logic = .{ .flipFlop = .{} }, .name = name[1..] };
            },
            '&' => {
                return .{ .logic = .{ .conjunction = .{} }, .name = name[1..] };
            },
            else => unreachable,
        }
    }

    fn processPulse(self: *ModuleLogic, pulse: Pulse) ?bool {
        return switch (self.*) {
            inline else => |*m| m.processPulse(pulse),
        };
    }

    fn addInput(self: *ModuleLogic, input: []const u8, modules: *std.StringHashMap(Module)) !void {
        switch (self.*) {
            inline else => |*m| {
                if (@hasDecl(@TypeOf(m.*), "addInput")) {
                    try m.addInput(input, modules);
                }
            },
        }
    }
};

const Broadcaster = struct {
    fn processPulse(_: *const Broadcaster, pulse: Pulse) ?bool {
        return pulse.high;
    }
};

const FlipFlop = struct {
    state: bool = false,

    fn processPulse(self: *FlipFlop, pulse: Pulse) ?bool {
        if (pulse.high) {
            return null;
        }

        self.state = !self.state;
        return self.state;
    }
};

const Conjunction = struct {
    inputs: std.SegmentedList(*Module, Module.CONNECTION_LIMIT * 2) = .{},
    inputStates: std.SegmentedList(bool, Module.CONNECTION_LIMIT * 2) = .{},
    firstHighPress: ?usize = null,

    fn processPulse(self: *Conjunction, pulse: Pulse) ?bool {
        var allHigh: bool = true;
        for (0..self.inputs.count()) |i| {
            if (pulse.source == self.inputs.at(i).*) {
                self.inputStates.at(i).* = pulse.high;
            }
            allHigh = allHigh and self.inputStates.at(i).*;
        }

        if (!allHigh and self.firstHighPress == null) {
            self.firstHighPress = buttonPresses;
        }

        return !allHigh;
    }

    fn addInput(self: *Conjunction, input: []const u8, modules: *std.StringHashMap(Module)) !void {
        const inputPtr = modules.getPtr(input).?;
        for (0..self.inputs.count()) |i| {
            if (self.inputs.at(i).* == inputPtr) {
                return;
            }
        }

        var buf = [0]u8{};
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var allocator = fba.allocator();

        var n = try self.inputs.addOne(allocator);
        n.* = inputPtr;

        var s = try self.inputStates.addOne(allocator);
        s.* = false;
    }
};

const Counter = struct {
    high: usize = 0,
    low: usize = 0,
    input: *Module = undefined,

    fn processPulse(self: *Counter, pulse: Pulse) ?bool {
        if (pulse.high) {
            self.high += 1;
        } else {
            self.low += 1;
        }
        return false;
    }
};
