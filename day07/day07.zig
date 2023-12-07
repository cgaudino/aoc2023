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

    std.mem.sort(Hand, hands.items, false, Hand.lessThan);
    var partOne: u32 = 0;
    for (hands.items, 0..) |hand, i| {
        partOne += @intCast(hand.bid * (i + 1));
    }
    std.debug.print("Part One: {d}\n", .{partOne});

    std.mem.sort(Hand, hands.items, true, Hand.lessThan);
    var partTwo: u32 = 0;
    for (hands.items, 0..) |hand, i| {
        partTwo += @intCast(hand.bid * (i + 1));
    }
    std.debug.print("Part Two: {d}\n", .{partTwo});
}

const Hand = struct {
    text: []const u8,
    cards: [5]u8,
    bid: u32,
    hand_type: HandType,
    hand_type_with_jokers: HandType,

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
            .hand_type_with_jokers = undefined,
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

        hand.hand_type = classifyHand(&counts, false);
        hand.hand_type_with_jokers = classifyHand(&counts, true);

        return hand;
    }

    fn lessThan(jokers_wild: bool, lhs: Hand, rhs: Hand) bool {
        const l_type = if (jokers_wild) lhs.hand_type_with_jokers else lhs.hand_type;
        const r_type = if (jokers_wild) rhs.hand_type_with_jokers else rhs.hand_type;

        if (l_type == r_type) {
            for (lhs.cards, rhs.cards) |l, r| {
                if (l != r) {
                    if (jokers_wild) {
                        if (l == 11) {
                            return r != 11;
                        }
                        if (r == 11) {
                            return false;
                        }
                    }
                    return l < r;
                }
            }
        }
        return @intFromEnum(l_type) < @intFromEnum(r_type);
    }

    fn classifyHand(counts: []u8, jokers_wild: bool) HandType {
        var numTrips: usize = 0;
        var numPairs: usize = 0;
        var numJokers: usize = if (jokers_wild) counts[11] else 0;

        for (counts, 0..) |count, i| {
            if (jokers_wild and i == 11) {
                continue;
            }

            switch (count) {
                5 => return .five_of_a_kind,
                4 => return if (numJokers > 0) .five_of_a_kind else .four_of_a_kind,
                3 => numTrips += 1,
                2 => numPairs += 1,
                else => {},
            }
        }

        switch (numTrips) {
            1 => {
                switch (numPairs) {
                    1 => return .full_house,
                    0 => return switch (numJokers) {
                        2 => .five_of_a_kind,
                        1 => .four_of_a_kind,
                        0 => .three_of_a_kind,
                        else => unreachable,
                    },
                    else => unreachable,
                }
            },
            0 => {},
            else => unreachable,
        }

        switch (numPairs) {
            2 => {
                return switch (numJokers) {
                    1 => return .full_house,
                    0 => return .two_pair,
                    else => unreachable,
                };
            },
            1 => {
                return switch (numJokers) {
                    3 => return .five_of_a_kind,
                    2 => return .four_of_a_kind,
                    1 => return .three_of_a_kind,
                    0 => return .one_pair,
                    else => unreachable,
                };
            },
            0 => {
                return switch (numJokers) {
                    5 => return .five_of_a_kind,
                    4 => return .five_of_a_kind,
                    3 => return .four_of_a_kind,
                    2 => return .three_of_a_kind,
                    1 => return .one_pair,
                    0 => return .high_card,
                    else => unreachable,
                };
            },
            else => unreachable,
        }

        unreachable;
    }
};
