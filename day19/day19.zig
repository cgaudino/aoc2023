const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(allocator, std.math.maxInt(u16));
    defer allocator.free(input);

    var workflowMap = std.StringHashMap(Workflow).init(allocator);
    defer workflowMap.deinit();

    var lineIter = std.mem.splitScalar(u8, input, '\n');
    while (lineIter.next()) |line| {
        if (line.len == 0) {
            break;
        }

        const workflow = try Workflow.parse(line);
        try workflowMap.put(workflow.name, workflow);
    }

    const firstWorkflow = "in";
    var sum: Part = .{};
    while (lineIter.next()) |line| {
        if (line.len == 0) {
            break;
        }

        const part = try Part.parse(line);
        if (processPart(&part, firstWorkflow, &workflowMap)) {
            sum = Part.add(sum, part);
        }
    }

    const partOne = sum.x + sum.m + sum.a + sum.s;
    std.debug.print("Part One: {d}\n", .{partOne});
}

fn processPart(part: *const Part, workflowName: []const u8, workflowMap: *std.StringHashMap(Workflow)) bool {
    if (workflowName.len == 1) {
        switch (workflowName[0]) {
            'A' => return true,
            'R' => return false,
            else => {},
        }
    }

    const workflow = workflowMap.get(workflowName).?;
    for (0..workflow.numRules) |i| {
        const rule = workflow.rules[i];
        if (rule.testPart(part)) {
            return processPart(part, rule.target, workflowMap);
        }
    }

    unreachable;
}

const Part = struct {
    x: i32 = 0,
    m: i32 = 0,
    a: i32 = 0,
    s: i32 = 0,

    fn parse(text: []const u8) !Part {
        var trimmed = std.mem.trim(u8, text, "{}");
        var iter = std.mem.tokenizeScalar(u8, trimmed, ',');

        return .{
            .x = try std.fmt.parseInt(i32, iter.next().?[2..], 10),
            .m = try std.fmt.parseInt(i32, iter.next().?[2..], 10),
            .a = try std.fmt.parseInt(i32, iter.next().?[2..], 10),
            .s = try std.fmt.parseInt(i32, iter.next().?[2..], 10),
        };
    }

    fn add(a: Part, b: Part) Part {
        return .{
            .x = a.x + b.x,
            .m = a.m + b.m,
            .a = a.a + b.a,
            .s = a.s + b.s,
        };
    }

    fn getProperty(self: *const Part, fieldName: u8) i32 {
        return switch (fieldName) {
            'x' => self.x,
            'm' => self.m,
            'a' => self.a,
            's' => self.s,
            else => 0,
        };
    }
};

const Workflow = struct {
    name: []const u8,
    numRules: usize,
    rules: [8]Rule = undefined,

    fn parse(text: []const u8) !Workflow {
        const braceIndex = std.mem.indexOfScalar(u8, text, '{').?;
        var workflow = Workflow{
            .name = text[0..braceIndex],
            .numRules = 0,
        };

        const rulesText = std.mem.trim(u8, text[braceIndex..], "{}");
        var ruleIter = std.mem.tokenizeScalar(u8, rulesText, ',');
        while (ruleIter.next()) |rule| {
            workflow.rules[workflow.numRules] = try Rule.parse(rule);
            workflow.numRules += 1;
        }
        return workflow;
    }
};

const Rule = struct {
    property: u8,
    operator: *const fn (i32, i32) bool,
    value: i32,
    target: []const u8,

    fn parse(text: []const u8) !Rule {
        if (std.mem.indexOfScalar(u8, text, ':')) |colonIndex| {
            const condition = text[0..colonIndex];
            const operatorIndex = std.mem.indexOfAny(u8, condition, "<>").?;

            return .{
                .property = condition[0],
                .operator = switch (condition[operatorIndex]) {
                    '>' => greaterThan,
                    '<' => lessThan,
                    else => unreachable,
                },
                .value = try std.fmt.parseInt(i32, condition[operatorIndex + 1 ..], 10),
                .target = text[colonIndex + 1 ..],
            };
        }
        return .{
            .property = 0,
            .operator = returnTrue,
            .value = 0,
            .target = text,
        };
    }

    fn testPart(self: *const Rule, part: *const Part) bool {
        const propertyValue = part.getProperty(self.property);
        const result = self.operator(propertyValue, self.value);
        return result;
    }
};

fn greaterThan(a: i32, b: i32) bool {
    return a > b;
}

fn lessThan(a: i32, b: i32) bool {
    return a < b;
}

fn returnTrue(_: i32, _: i32) bool {
    return true;
}
