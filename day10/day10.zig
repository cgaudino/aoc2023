const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    const gridWidth = std.mem.indexOfScalar(u8, input, '\n').? + 1;
    const startPosition = std.mem.indexOfScalar(u8, input, 'S').?;

    var position = startPosition;
    var direction = findFirstMove(startPosition, gridWidth, input);
    var iterations: usize = 0;
    while (position != startPosition or iterations == 0) : (iterations += 1) {
        position = try doMove(position, direction, gridWidth);
        direction = getNewDirection(direction, input[position]);
    }

    std.debug.print("Part One: {d}\n", .{iterations / 2});
}

const Direction = enum { up, down, left, right, invalid };
const MoveError = error.InvalidDirection;

fn doMove(position: usize, dir: Direction, gridWidth: usize) !usize {
    const negative = dir == .left or dir == .up;
    const diff = switch (dir) {
        .up, .down => gridWidth,
        .left, .right => 1,
        else => return error.InvalidDirection,
    };
    if (negative and position < diff) {
        return error.InvalidDirection;
    }
    return if (negative) position - diff else position + diff;
}

fn findFirstMove(startPosition: usize, gridWidth: usize, map: []const u8) Direction {
    const candidates = [4]Direction{ .left, .right, .up, .down };

    for (candidates) |candidate| {
        const testPosition = doMove(startPosition, candidate, gridWidth) catch {
            continue;
        };
        if (testPosition >= map.len) {
            continue;
        }
        const dir = getNewDirection(candidate, map[testPosition]);
        if (dir != .invalid) {
            return candidate;
        }
    }

    return .invalid;
}

fn getNewDirection(currentDirection: Direction, tile: u8) Direction {
    return switch (currentDirection) {
        .up => switch (tile) {
            '|' => .up,
            'F' => .right,
            '7' => .left,
            else => .invalid,
        },
        .down => switch (tile) {
            '|' => .down,
            'J' => .left,
            'L' => .right,
            else => .invalid,
        },
        .left => switch (tile) {
            '-' => .left,
            'F' => .down,
            'L' => .up,
            else => .invalid,
        },
        .right => switch (tile) {
            '-' => .right,
            'J' => .up,
            '7' => .down,
            else => .invalid,
        },
        else => .invalid,
    };
}
