const std = @import("std");

pub fn main() !void {
    const file = try std.fs.cwd().openFile("input.txt", .{});
    defer file.close();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();

    const input = try file.readToEndAlloc(alloc, std.math.maxInt(u16));
    defer alloc.free(input);

    var hands = std.ArrayList(Hand).init(alloc);
    defer hands.deinit();

    var linesIter = std.mem.tokenizeScalar(u8, input, '\n');
    while (linesIter.next()) |line| {
        try hands.append(try Hand.parse(line));
    }

    std.mem.sort(Hand, hands.items, {}, Hand.lessThan);

    var partOne: u32 = 0;
    for (hands.items, 0..) |hand, i| {
        partOne += @intCast(hand.bid * (i + 1));
    }

    std.debug.print("Part One: {d}\n", .{partOne});
}

const Hand = struct {
    text: []const u8,
    cards: [5]u8,
    bid: u32,
    hand_type: HandType,

    const HandType = enum(u8) {
        high_card,
        one_pair,
        two_pair,
        three_of_a_kind,
        full_house,
        four_of_a_kind,
        five_of_a_kind,
    };

    pub fn parse(input: []const u8) !Hand {
        var hand: Hand = .{
            .text = input[0..5],
            .cards = undefined,
            .bid = try std.fmt.parseInt(u32, input[6..], 10),
            .hand_type = undefined,
        };

        var counts = [1]u8{0} ** 15;
        for (hand.text, hand.cards, 0..) |t, _, i| {
            hand.cards[i] = switch (t) {
                'A' => 14,
                'K' => 13,
                'Q' => 12,
                'J' => 11,
                'T' => 10,
                inline '0'...'9' => t - '0',
                else => unreachable,
            };
            counts[hand.cards[i]] += 1;
        }

        hand.hand_type = classifyHand(&counts);

        return hand;
    }

    fn lessThan(_: void, lhs: Hand, rhs: Hand) bool {
        if (lhs.hand_type == rhs.hand_type) {
            for (lhs.cards, rhs.cards) |l, r| {
                if (l != r) {
                    return l < r;
                }
            }
        }
        return @intFromEnum(lhs.hand_type) < @intFromEnum(rhs.hand_type);
    }

    fn classifyHand(counts: []u8) HandType {
        var numTrips: usize = 0;
        var numPairs: usize = 0;

        for (counts) |count| {
            switch (count) {
                5 => return .five_of_a_kind,
                4 => return .four_of_a_kind,
                3 => numTrips += 1,
                2 => numPairs += 1,
                else => continue,
            }
        }

        if (numTrips == 1) {
            return switch (numPairs) {
                1 => .full_house,
                0 => .three_of_a_kind,
                else => undefined,
            };
        }

        return switch (numPairs) {
            2 => .two_pair,
            1 => .one_pair,
            0 => .high_card,
            else => undefined,
        };
    }
};
