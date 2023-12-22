const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var partOne = Calculation{};
    var partTwo = Calculation{};

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (lineIter.next()) |line| {
        const stepOne = try DigStep.parsePartOne(line);
        partOne.processStep(stepOne);

        const stepTwo = try DigStep.parsePartTwo(line);
        partTwo.processStep(stepTwo);
    }

    std.debug.print("Part One: {d}\nPart Two: {d}\n", .{ partOne.finalize(), partTwo.finalize() });
}

const Vec2 = @Vector(2, i64);

const Calculation = struct {
    pos: Vec2 = Vec2{ 0, 0 },
    sumA: i64 = 0,
    sumB: i64 = 0,
    perimeterLength: i64 = 0,

    fn processStep(self: *Calculation, step: DigStep) void {
        self.perimeterLength += step.magnitude;

        const next = self.pos + (step.direction * Vec2{ step.magnitude, step.magnitude });
        self.sumA += self.pos[0] * next[1];
        self.sumB += self.pos[1] * next[0];
        self.pos = next;
    }

    fn finalize(self: Calculation) i64 {
        const area = @abs(self.sumA - self.sumB) / 2;
        const interiorPoints = @as(i64, @intCast(area)) - (@divFloor(self.perimeterLength, 2)) + 1;
        return interiorPoints + self.perimeterLength;
    }
};

const DigStep = struct {
    direction: Vec2,
    magnitude: i64,

    fn parsePartOne(text: []const u8) !DigStep {
        var tokenIter = std.mem.tokenizeScalar(u8, text, ' ');
        return .{
            .direction = switch (tokenIter.next().?[0]) {
                'R' => Vec2{ 1, 0 },
                'L' => Vec2{ -1, 0 },
                'U' => Vec2{ 0, -1 },
                'D' => Vec2{ 0, 1 },
                else => unreachable,
            },
            .magnitude = try std.fmt.parseInt(i64, tokenIter.next().?, 10),
        };
    }

    fn parsePartTwo(text: []const u8) !DigStep {
        var startIndex = std.mem.indexOfScalar(u8, text, '#').? + 1;
        const magnitudeSlice = text[startIndex .. startIndex + 5];
        const directionDigit = text[startIndex + 5];
        return .{
            .direction = switch (directionDigit) {
                '0' => Vec2{ 1, 0 },
                '1' => Vec2{ 0, 1 },
                '2' => Vec2{ -1, 0 },
                '3' => Vec2{ 0, -1 },
                else => unreachable,
            },
            .magnitude = try std.fmt.parseInt(i64, magnitudeSlice, 16),
        };
    }
};
