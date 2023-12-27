const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var bricks = std.ArrayList(Brick).init(allocator);
    defer {
        for (bricks.items) |*brick| {
            brick.deinit();
        }
        bricks.deinit();
    }

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (lineIter.next()) |line| {
        try bricks.append(try Brick.parse(line, allocator));
    }

    std.mem.sort(Brick, bricks.items, {}, Brick.lowerThan);

    for (bricks.items, 0..) |*brick, i| {
        try brick.fall(bricks.items[0..i]);
    }

    var affectedBricks = std.AutoHashMap(*Brick, void).init(allocator);
    defer affectedBricks.deinit();

    var partOne: usize = 0;
    var partTwo: usize = 0;
    for (bricks.items) |*brick| {
        var canDissolve = true;
        var supportsIter = brick.supports.constIterator(0);
        while (supportsIter.next()) |other| {
            if (other.*.supportedBy.count() == 1) {
                canDissolve = false;
                break;
            }
        }
        if (canDissolve) {
            partOne += 1;
        }

        affectedBricks.clearRetainingCapacity();
        try addAffectedBricks(brick, &affectedBricks);
        partTwo += affectedBricks.count();
    }

    std.debug.print("Part One: {d}\nPart Two: {d}\n", .{ partOne, partTwo });
}

const Vec3 = @Vector(3, isize);
const zero = Vec3{ 0, 0, 0 };
const up = Vec3{ 0, 0, 1 };
const one = Vec3{ 1, 1, 1 };

const Brick = struct {
    start: Vec3 = .{ 0, 0, 0 },
    end: Vec3 = .{ 0, 0, 0 },

    supports: std.SegmentedList(*Brick, 8),
    supportedBy: std.SegmentedList(*Brick, 8),
    allocator: std.mem.Allocator,

    fn parse(text: []const u8, allocator: std.mem.Allocator) !Brick {
        var brick: Brick = .{
            .supports = std.SegmentedList(*Brick, 8){},
            .supportedBy = std.SegmentedList(*Brick, 8){},
            .allocator = allocator,
        };

        var numIter = std.mem.tokenizeAny(u8, text, ",~");

        for (0..3) |i| {
            brick.start[i] = try std.fmt.parseInt(isize, numIter.next().?, 10);
        }
        for (0..3) |i| {
            brick.end[i] = try std.fmt.parseInt(isize, numIter.next().?, 10);
        }
        return brick;
    }

    fn deinit(self: *Brick) void {
        self.supports.deinit(self.allocator);
        self.supportedBy.deinit(self.allocator);
    }

    fn lowerThan(_: void, a: Brick, b: Brick) bool {
        return @min(a.start[2], a.end[2]) < @min(b.start[2], b.end[2]);
    }

    fn fall(self: *Brick, bricks: []Brick) !void {
        while (self.start[2] > 1 and self.end[2] > 1 and self.supportedBy.count() == 0) {
            var o = bricks.len;
            while (o > 0) {
                o -= 1;
                var other = &bricks[o];
                if (intersects(self.start - up, self.end - up, other.*.start, other.*.end)) {
                    try other.*.supports.append(self.allocator, self);
                    try self.supportedBy.append(self.allocator, other);
                }
            }

            if (self.supportedBy.count() == 0) {
                self.start -= up;
                self.end -= up;
            }
        }
    }
};

fn intersects(start: Vec3, end: Vec3, otherStart: Vec3, otherEnd: Vec3) bool {
    var selfIter = Vec3Iterator.init(start, end);
    while (selfIter.next()) |a| {
        var otherIter = Vec3Iterator.init(otherStart, otherEnd);
        while (otherIter.next()) |b| {
            if (@reduce(.And, a == b)) {
                return true;
            }
        }
    }
    return false;
}

fn addAffectedBricks(moved: *Brick, set: *std.AutoHashMap(*Brick, void)) !void {
    var supportsIter = moved.supports.iterator(0);
    while (supportsIter.next()) |other| {
        if (other.*.supportedBy.count() == 1 or containsAll(set, other.*.supportedBy.iterator(0))) {
            try set.put(other.*, {});
        }
    }
    supportsIter.set(0);
    while (supportsIter.next()) |other| {
        if (set.contains(other.*)) {
            try addAffectedBricks(other.*, set);
        }
    }
}

fn containsAll(set: *std.AutoHashMap(*Brick, void), iter: std.SegmentedList(*Brick, 8).Iterator) bool {
    var i = iter;
    while (i.next()) |ptr| {
        if (!set.contains(ptr.*)) {
            return false;
        }
    }
    return true;
}

const Vec3Iterator = struct {
    curr: Vec3,
    last: Vec3,
    step: Vec3,

    fn init(start: Vec3, end: Vec3) Vec3Iterator {
        var s = start;
        var e = end;
        if (@reduce(.Or, start > end)) {
            s = end;
            e = start;
        }
        const diff = e - s;
        const zeros = diff == zero;
        var step = std.math.sign(diff) * @select(isize, zeros, zero, one);

        if (@reduce(.Add, step) == 0) {
            step = Vec3{ 1, 0, 0 };
        }

        return .{
            .curr = s,
            .last = e + step,
            .step = step,
        };
    }

    fn next(self: *Vec3Iterator) ?Vec3 {
        if (@reduce(.And, self.curr == self.last)) {
            return null;
        }

        const result = self.curr;
        self.curr += self.step;
        return result;
    }
};
