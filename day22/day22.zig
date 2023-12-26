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

    var partOne: usize = 0;
    for (bricks.items) |brick| {
        var canDissolve = true;
        for (brick.supports.items) |other| {
            if (other.supportedBy.items.len == 1) {
                canDissolve = false;
                break;
            }
        }
        if (canDissolve) {
            partOne += 1;
        }
    }

    std.debug.print("Part One: {d}\n", .{partOne});
}

const Vec3 = @Vector(3, isize);
const zero = Vec3{ 0, 0, 0 };
const up = Vec3{ 0, 0, 1 };
const one = Vec3{ 1, 1, 1 };

const Brick = struct {
    start: Vec3 = .{ 0, 0, 0 },
    end: Vec3 = .{ 0, 0, 0 },

    supports: std.ArrayList(*Brick),
    supportedBy: std.ArrayList(*Brick),

    fn parse(text: []const u8, allocator: std.mem.Allocator) !Brick {
        var brick: Brick = .{
            .supports = std.ArrayList(*Brick).init(allocator),
            .supportedBy = std.ArrayList(*Brick).init(allocator),
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
        self.supports.deinit();
        self.supportedBy.deinit();
    }

    fn lowerThan(_: void, a: Brick, b: Brick) bool {
        return @min(a.start[2], a.end[2]) < @min(b.start[2], b.end[2]);
    }

    fn fall(self: *Brick, bricks: []Brick) !void {
        while (self.start[2] > 1 and self.end[2] > 1 and self.supportedBy.items.len == 0) {
            var o = bricks.len;
            while (o > 0) {
                o -= 1;
                var other = &bricks[o];
                if (intersects(self.start - up, self.end - up, other.*.start, other.*.end)) {
                    try other.*.supports.append(self);
                    try self.supportedBy.append(other);
                }
            }

            if (self.supportedBy.items.len == 0) {
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
