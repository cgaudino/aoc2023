const std = @import("std");

pub fn main() !void {
    var timer = try std.time.Timer.start();
    defer {
        const elapsed = timer.read();
        std.debug.print("Finished in {d}ms", .{@as(f32, @floatFromInt(elapsed)) / std.time.ns_per_ms});
    }

    const file = try std.fs.cwd().openFile("input.txt", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var grid = try Grid.init(allocator, input);
    defer grid.deinit();

    fireBeam(.{ -1, 0 }, right, &grid);
    std.debug.print("Part One: {d}\n", .{grid.numCellsVisited});

    var highest: usize = grid.numCellsVisited;
    var x: isize = 0;
    while (x < grid.extents[0]) : (x += 1) {
        grid.reset();
        const topPos = Vec2{ x, -1 };
        fireBeam(topPos, down, &grid);
        highest = @max(highest, grid.numCellsVisited);

        grid.reset();
        const botPos = Vec2{ x, grid.extents[1] };
        fireBeam(botPos, up, &grid);
        highest = @max(highest, grid.numCellsVisited);
    }
    var y: isize = 0;
    while (y < grid.extents[1]) : (y += 1) {
        grid.reset();
        const leftPos = Vec2{ -1, y };
        fireBeam(leftPos, right, &grid);
        highest = @max(highest, grid.numCellsVisited);

        grid.reset();
        const rightPos = Vec2{ grid.extents[0], y };
        fireBeam(rightPos, left, &grid);
        highest = @max(highest, grid.numCellsVisited);
    }

    std.debug.print("Part Two: {d}\n", .{highest});
}

fn fireBeam(pos: Vec2, dir: Vec2, grid: *Grid) void {
    if (grid.tryMove(pos, dir)) |newPos| {
        if (grid.visitCell(newPos, dir)) |bounce| {
            fireBeam(newPos, bounce.newDir, grid);
            if (bounce.splitDir) |splitDir| {
                fireBeam(newPos, splitDir, grid);
            }
        }
    }
}

const Vec2 = @Vector(2, isize);

const zero = Vec2{ 0, 0 };
const up = Vec2{ 0, -1 };
const down = Vec2{ 0, 1 };
const left = Vec2{ -1, 0 };
const right = Vec2{ 1, 0 };

const Beam = struct {
    pos: Vec2,
    dir: Vec2,
};

const Cell = struct {
    symbol: u8,
    visited: u8 = 0,

    fn visitFromDir(self: *Cell, dir: Vec2) bool {
        var dirRepeated = false;
        if (@reduce(.And, dir == up)) {
            dirRepeated = (self.visited & (1 << 0)) != 0;
            self.visited |= 1 << 0;
        } else if (@reduce(.And, dir == down)) {
            dirRepeated = (self.visited & (1 << 1)) != 0;
            self.visited |= 1 << 1;
        } else if (@reduce(.And, dir == left)) {
            dirRepeated = (self.visited & (1 << 2)) != 0;
            self.visited |= 1 << 2;
        } else if (@reduce(.And, dir == right)) {
            dirRepeated = (self.visited & (1 << 3)) != 0;
            self.visited |= 1 << 3;
        }
        return dirRepeated;
    }

    fn reset(self: *Cell) void {
        self.visited = 0;
    }
};

const Grid = struct {
    cells: std.ArrayList(Cell),
    extents: Vec2,
    numCellsVisited: usize = 0,

    fn init(allocator: std.mem.Allocator, input: []const u8) !Grid {
        var cells = std.ArrayList(Cell).init(allocator);
        var gridWidth: isize = 0;
        var linesIter = std.mem.tokenizeScalar(u8, input, '\n');
        while (linesIter.next()) |line| {
            gridWidth = if (gridWidth == 0 or gridWidth == line.len) @intCast(line.len) else unreachable;
            for (line) |symbol| {
                try cells.append(.{ .symbol = symbol });
            }
        }
        return .{
            .cells = cells,
            .extents = .{ gridWidth, @divExact(@as(isize, @intCast(cells.items.len)), gridWidth) },
        };
    }

    fn deinit(self: *Grid) void {
        self.cells.deinit();
    }

    fn tryMove(self: *Grid, pos: Vec2, dir: Vec2) ?Vec2 {
        const result = pos + dir;
        if (@reduce(.And, result >= zero) and @reduce(.And, result < self.extents)) {
            return result;
        }
        return null;
    }

    fn visitCell(self: *Grid, pos: Vec2, dir: Vec2) ?struct { newDir: Vec2, splitDir: ?Vec2 } {
        var cell = &(self.cells.items[@intCast(pos[1] * self.extents[0] + pos[0])]);
        if (cell.visited == 0) {
            self.numCellsVisited += 1;
        }
        if (cell.visitFromDir(dir)) {
            return null;
        }
        switch (cell.symbol) {
            '|' => {
                if (dir[1] == 0) {
                    return .{ .newDir = up, .splitDir = down };
                }
            },
            '-' => {
                if (dir[0] == 0) {
                    return .{ .newDir = left, .splitDir = right };
                }
            },
            '\\' => {
                if (@reduce(.And, dir == up)) {
                    return .{ .newDir = left, .splitDir = null };
                }
                if (@reduce(.And, dir == down)) {
                    return .{ .newDir = right, .splitDir = null };
                }
                if (@reduce(.And, dir == left)) {
                    return .{ .newDir = up, .splitDir = null };
                }
                if (@reduce(.And, dir == right)) {
                    return .{ .newDir = down, .splitDir = null };
                }
            },
            '/' => {
                if (@reduce(.And, dir == up)) {
                    return .{ .newDir = right, .splitDir = null };
                }
                if (@reduce(.And, dir == down)) {
                    return .{ .newDir = left, .splitDir = null };
                }
                if (@reduce(.And, dir == left)) {
                    return .{ .newDir = down, .splitDir = null };
                }
                if (@reduce(.And, dir == right)) {
                    return .{ .newDir = up, .splitDir = null };
                }
            },
            else => {},
        }
        return .{ .newDir = dir, .splitDir = null };
    }

    fn reset(self: *Grid) void {
        self.numCellsVisited = 0;
        for (self.cells.items) |*cell| {
            cell.reset();
        }
    }
};
