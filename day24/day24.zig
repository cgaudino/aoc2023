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

    var ps: [3]Projectile = undefined;
    findIndependentProjectiles(projectiles.items, &ps);
    const partTwo = findRock(&ps);

    std.debug.print("Part Two: {d}\n", .{partTwo});
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

fn dot(a: Vec3, b: Vec3) f64 {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

fn cross(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

fn lerp(r: f64, a: Vec3, s: f64, b: Vec3, t: f64, c: Vec3) Vec3 {
    return .{
        r * a[0] + s * b[0] + t * c[0],
        r * a[1] + s * b[1] + t * c[1],
        r * a[2] + s * b[2] + t * c[2],
    };
}

fn independent(a: Vec3, b: Vec3) bool {
    return @reduce(.Or, cross(a, b) != @as(Vec3, @splat(0)));
}

fn toPlane(a: Projectile, b: Projectile) struct { normal: Vec3, distance: f64 } {
    const p = a.pos - b.pos;
    const v = a.vel - b.vel;
    const c = cross(a.vel, b.vel);
    return .{
        .normal = cross(p, v),
        .distance = dot(p, c),
    };
}

fn findIndependentProjectiles(projectiles: []Projectile, buffer: *[3]Projectile) void {
    buffer[0] = projectiles[0];
    var i: usize = 1;
    for (projectiles) |other| {
        if (i == 1 and independent(buffer[0].vel, other.vel)) {
            buffer[i] = other;
            i += 1;
            continue;
        }
        if (i == 2 and independent(buffer[0].vel, other.vel) and independent(buffer[1].vel, other.vel)) {
            buffer[i] = other;
            break;
        }
    }
}

fn findRock(projectiles: *[3]Projectile) f64 {
    const planeA = toPlane(projectiles[0], projectiles[1]);
    const planeB = toPlane(projectiles[0], projectiles[2]);
    const planeC = toPlane(projectiles[1], projectiles[2]);

    const t = dot(planeA.normal, cross(planeB.normal, planeC.normal));
    var w = lerp(
        planeA.distance,
        cross(planeB.normal, planeC.normal),
        planeB.distance,
        cross(planeC.normal, planeA.normal),
        planeC.distance,
        cross(planeA.normal, planeB.normal),
    );
    w[0] = @round(w[0] / t);
    w[1] = @round(w[1] / t);
    w[2] = @round(w[2] / t);

    const w1 = projectiles[0].vel - w;
    const w2 = projectiles[1].vel - w;
    const ww = cross(w1, w2);

    const a = dot(ww, cross(projectiles[1].pos, w2));
    const b = dot(ww, cross(projectiles[0].pos, w1));
    const c = dot(projectiles[0].pos, ww);
    const d = dot(ww, ww);

    const rock = lerp(a, w1, -b, w2, c, ww);

    return @reduce(.Add, rock) / d;
}
