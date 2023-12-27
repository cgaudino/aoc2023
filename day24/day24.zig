const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var projectiles = std.ArrayList(Projectile).init(allocator);
    defer projectiles.deinit();

    var lineIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (lineIter.next()) |line| {
        try projectiles.append(try Projectile.parse(line));
    }

    const min: f64 = 200000000000000;
    const max: f64 = 400000000000000;
    var buffer = [2]f64{ 0, 0 };
    var sum: usize = 0;
    for (0..projectiles.items.len - 1) |a| {
        for (a + 1..projectiles.items.len) |b| {
            const result = findIntersection(projectiles.items[a], projectiles.items[b], &buffer) orelse continue;
            if (result[0] >= min and result[0] <= max and result[1] >= min and result[1] <= max) {
                sum += 1;
            }
        }
    }
    std.debug.print("Part One: {d}\n", .{sum});
}

const Vec3 = @Vector(3, f64);

fn parseVec3(text: []const u8) !Vec3 {
    var iter = std.mem.tokenizeScalar(u8, text, ',');
    return .{
        try std.fmt.parseFloat(f64, std.mem.trim(u8, iter.next().?, " ")),
        try std.fmt.parseFloat(f64, std.mem.trim(u8, iter.next().?, " ")),
        try std.fmt.parseFloat(f64, std.mem.trim(u8, iter.next().?, " ")),
    };
}

const Projectile = struct {
    pos: Vec3,
    vel: Vec3,

    fn parse(text: []const u8) !Projectile {
        var iter = std.mem.tokenizeScalar(u8, text, '@');
        return .{
            .pos = try parseVec3(iter.next().?),
            .vel = try parseVec3(iter.next().?),
        };
    }
};

fn findIntersection(a: Projectile, b: Projectile, buffer: *[2]f64) ?[]f64 {
    const d = a.vel[0] * b.vel[1] - a.vel[1] * b.vel[0];
    if (std.math.approxEqAbs(f64, d, 0, std.math.floatEps(f64) * 2)) {
        return null;
    }
    const t = ((b.pos[0] - a.pos[0]) * b.vel[1] - (b.pos[1] - a.pos[1]) * b.vel[0]) / d;
    buffer[0] = a.pos[0] + t * a.vel[0];
    buffer[1] = a.pos[1] + t * a.vel[1];
    if (isInPast(a, buffer) or isInPast(b, buffer)) {
        return null;
    }
    return buffer[0..];
}

fn isInPast(a: Projectile, b: *[2]f64) bool {
    const x = a.pos[0] + a.vel[0];
    const y = a.pos[1] + a.vel[1];
    return @abs(x - b[0]) + @abs(y - b[1]) > @abs(a.pos[0] - b[0]) + @abs(a.pos[1] - b[1]);
}
