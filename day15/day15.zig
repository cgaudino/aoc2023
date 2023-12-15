const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var tokenIter = std.mem.tokenizeScalar(u8, input, ',');
    var hashSum: u64 = 0;
    var hashmap = HashMap.init(allocator);
    defer hashmap.deinit();

    while (tokenIter.next()) |token| {
        hashSum += HashMap.hash(token);

        const instruction = try parseInstruction(token);
        try hashmap.performInstruction(instruction.label, instruction.operation, instruction.focalLength);
    }

    const focusingPower = hashmap.calcFocusingPower();

    std.debug.print("Part One: {d}\nPart Two: {d}\n", .{ hashSum, focusingPower });
}

fn parseInstruction(string: []const u8) !struct { label: []const u8, operation: u8, focalLength: u64 } {
    const operationIndex = std.mem.indexOfAny(u8, string, "-=").?;
    const endIndex = if (std.mem.indexOfScalar(u8, string, '\n')) |index| index else string.len;

    return .{
        .label = string[0..operationIndex],
        .operation = string[operationIndex],
        .focalLength = if (operationIndex + 1 < endIndex) try std.fmt.parseInt(u64, string[operationIndex + 1 .. endIndex], 10) else 0,
    };
}

const Lens = struct {
    label: []const u8,
    focalLength: u64,
};

const HashMap = struct {
    boxes: [256]std.ArrayList(Lens),

    fn init(allocator: std.mem.Allocator) HashMap {
        var hashMap: HashMap = .{ .boxes = undefined };

        for (hashMap.boxes, 0..) |_, i| {
            hashMap.boxes[i] = std.ArrayList(Lens).init(allocator);
        }

        return hashMap;
    }

    fn deinit(self: *HashMap) void {
        for (self.boxes) |box| {
            box.deinit();
        }
    }

    fn performInstruction(self: *HashMap, label: []const u8, operation: u8, focalLength: u64) !void {
        const h = hash(label);
        switch (operation) {
            '-' => {
                if (indexOfInBox(self, h, label)) |i| {
                    _ = self.boxes[h].orderedRemove(i);
                }
            },
            '=' => {
                if (indexOfInBox(self, h, label)) |i| {
                    self.boxes[h].items[i] = .{
                        .label = label,
                        .focalLength = focalLength,
                    };
                } else {
                    try self.boxes[h].append(.{
                        .label = label,
                        .focalLength = focalLength,
                    });
                }
            },
            else => {
                unreachable;
            },
        }
    }

    fn indexOfInBox(self: *HashMap, box: usize, label: []const u8) ?usize {
        for (self.boxes[box].items, 0..) |lens, i| {
            if (std.mem.eql(u8, lens.label, label)) {
                return i;
            }
        }
        return null;
    }

    fn hash(string: []const u8) u64 {
        var h: u64 = 0;
        for (string) |char| {
            if (char == '\n') {
                continue;
            }
            h += char;
            h *= 17;
            h %= 256;
        }
        return h;
    }

    fn calcFocusingPower(self: *HashMap) u64 {
        var result: u64 = 0;
        for (self.boxes, 0..) |box, b| {
            for (box.items, 0..) |lens, l| {
                result += (b + 1) * (l + 1) * lens.focalLength;
            }
        }
        return result;
    }
};
