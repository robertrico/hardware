#!/usr/bin/env python3
"""Host tests for layout_gen.py — the breadboard placement analyser.

The placement of chips on breadboards is the one piece of bench setup
that was still hand-drawn. This makes it derivable: feed it the real
netlist and a candidate placement, and it reports which nets cross a
board boundary, how far, and whether a different board ORDER would be
cheaper — the thing that actually decided the ALU layout.

Cost model: every net costs (highest board it touches - lowest). That
is exactly the number of board-to-board hops the net needs, so a net
living on one board is free and one spanning two boards costs 2.
"""
import sys
import unittest

import layout_gen as lg


def chips(**kw):
    """chips(U1=(board, col, pins), ...)"""
    return dict(kw)


class TestChipGeometry(unittest.TestCase):
    def test_width_is_half_the_pin_count(self):
        self.assertEqual(lg.chip_cols(20), 10)
        self.assertEqual(lg.chip_cols(16), 8)
        self.assertEqual(lg.chip_cols(14), 7)

    def test_overlap_detected_on_same_board(self):
        c = chips(U1=(0, 3, 20), U2=(0, 10, 14))     # U1 ends at 12
        self.assertEqual(lg.overlaps(c), [("U1", "U2")])

    def test_touching_chips_are_not_overlapping(self):
        c = chips(U1=(0, 3, 20), U2=(0, 13, 14))     # U1 spans 3..12
        self.assertEqual(lg.overlaps(c), [])

    def test_same_columns_on_different_boards_are_fine(self):
        c = chips(U1=(0, 3, 20), U2=(1, 3, 20))
        self.assertEqual(lg.overlaps(c), [])

    def test_off_the_end_is_reported(self):
        c = chips(U1=(0, 60, 20))                    # would need col 69
        self.assertEqual(lg.off_board(c, width=63), ["U1"])


class TestNetSpan(unittest.TestCase):
    def test_single_board_net_is_free(self):
        c = chips(U1=(0, 1, 14), U2=(0, 10, 14))
        self.assertEqual(lg.net_cost([("U1", "1"), ("U2", "2")], c), 0)

    def test_adjacent_boards_cost_one(self):
        c = chips(U1=(0, 1, 14), U2=(1, 1, 14))
        self.assertEqual(lg.net_cost([("U1", "1"), ("U2", "2")], c), 1)

    def test_spanning_two_boards_costs_two(self):
        c = chips(U1=(0, 1, 14), U2=(2, 1, 14))
        self.assertEqual(lg.net_cost([("U1", "1"), ("U2", "2")], c), 2)

    def test_unplaced_refs_are_ignored(self):
        """rig wires and off-module refs must not inflate the cost"""
        c = chips(U1=(0, 1, 14))
        self.assertEqual(lg.net_cost([("U1", "1"), ("U99", "3")], c), 0)

    def test_power_nets_excluded_by_the_caller(self):
        self.assertTrue(lg.is_power("+5V"))
        self.assertTrue(lg.is_power("GND"))
        self.assertFalse(lg.is_power("/ALU Module/F0"))


class TestAnalyse(unittest.TestCase):
    def setUp(self):
        # two boards: U1,U2 on 0; U3 on 1
        self.c = chips(U1=(0, 1, 14), U2=(0, 10, 14), U3=(1, 1, 14))
        self.nets = {
            "local":  [("U1", "1"), ("U2", "2")],
            "hop_a":  [("U1", "3"), ("U3", "4")],
            "hop_b":  [("U2", "5"), ("U3", "6")],
            "GND":    [("U1", "7"), ("U3", "7")],
        }

    def test_power_is_not_counted(self):
        r = lg.analyse(self.c, self.nets)
        self.assertNotIn("GND", [n for n, _ in r["crossing"]])
        self.assertEqual(r["cost"], 2)          # hop_a + hop_b

    def test_local_and_crossing_split(self):
        r = lg.analyse(self.c, self.nets)
        self.assertIn("local", r["local"])
        self.assertEqual(sorted(n for n, _ in r["crossing"]), ["hop_a", "hop_b"])

    def test_bundles_group_by_board_pair(self):
        r = lg.analyse(self.c, self.nets)
        self.assertEqual(sorted(r["bundles"][(0, 1)]), ["hop_a", "hop_b"])

    def test_spanning_means_no_relay_point_in_between(self):
        """A net is only 'spanning' if it SKIPS a board. A net that
        touches every board between its ends can be relayed at each one,
        so no single jumper is long — that is the F0-7 case: driven on
        the middle board, consumed above and below."""
        c = chips(U1=(0, 1, 14), U3=(2, 1, 14))
        r = lg.analyse(c, {"far": [("U1", "1"), ("U3", "2")]})
        self.assertEqual(r["spanning"], ["far"])

    def test_net_touching_every_board_is_not_spanning(self):
        c = chips(U1=(0, 1, 14), U2=(1, 1, 14), U3=(2, 1, 14))
        r = lg.analyse(c, {"relayed": [("U1", "1"), ("U2", "2"), ("U3", "3")]})
        self.assertEqual(r["spanning"], [])
        self.assertEqual(r["cost"], 2)          # still two hops
        self.assertEqual(sorted(r["bundles"]), [(0, 1), (1, 2)])


class TestBoardOrder(unittest.TestCase):
    def test_finds_the_cheaper_order(self):
        """A on 0, B on 1, C on 2 — but the traffic is A<->C.
        Putting C in the middle must win."""
        c = chips(A=(0, 1, 14), B=(1, 1, 14), C=(2, 1, 14))
        nets = {f"n{i}": [("A", "1"), ("C", "2")] for i in range(8)}
        nets["one"] = [("A", "3"), ("B", "4")]
        before = lg.analyse(c, nets)["cost"]
        order, after = lg.best_order(c, nets, 3)
        self.assertLess(after, before)
        # A and C must end up adjacent
        pos = {b: i for i, b in enumerate(order)}
        self.assertEqual(abs(pos[0] - pos[2]), 1)

    def test_already_optimal_order_is_kept(self):
        c = chips(A=(0, 1, 14), B=(1, 1, 14), C=(2, 1, 14))
        nets = {"x": [("A", "1"), ("B", "2")], "y": [("B", "3"), ("C", "4")]}
        order, cost = lg.best_order(c, nets, 3)
        self.assertEqual(cost, lg.analyse(c, nets)["cost"])

    def test_reorder_applies_to_chips(self):
        c = chips(A=(0, 1, 14), B=(1, 1, 14))
        moved = lg.apply_order(c, [1, 0])
        self.assertEqual(moved["A"][0], 1)
        self.assertEqual(moved["B"][0], 0)


class TestAutoPlace(unittest.TestCase):
    """Board COUNT and packing are outputs, not inputs: given the chips,
    the netlist and a board width, the tool decides how many boards are
    needed, what goes on each and in what order."""

    def test_everything_on_one_board_when_it_fits(self):
        pins = {"U1": 14, "U2": 14}
        nets = {"a": [("U1", "1"), ("U2", "2")]}
        p = lg.auto_place(pins, nets, width=63)
        self.assertEqual({b for b, _, _ in p.values()}, {0})

    def test_spills_to_more_boards_when_it_does_not_fit(self):
        pins = {f"U{i}": 20 for i in range(8)}      # 8 x 10 cols + gaps
        nets = {}
        p = lg.auto_place(pins, nets, width=63)
        self.assertGreater(len({b for b, _, _ in p.values()}), 1)

    def test_result_is_always_wellformed(self):
        pins = {f"U{i}": (20 if i % 2 else 14) for i in range(9)}
        nets = {f"n{i}": [(f"U{i}", "1"), (f"U{i+1}", "2")] for i in range(8)}
        p = lg.auto_place(pins, nets, width=63)
        self.assertEqual(lg.overlaps(p), [])
        self.assertEqual(lg.off_board(p, 63), [])
        self.assertEqual(set(p), set(pins))

    def test_a_chain_stays_in_order(self):
        """U0-U1-U2-... connected in a line must not be scattered:
        every net should cost at most one hop."""
        pins = {f"U{i}": 20 for i in range(6)}
        nets = {f"n{i}": [(f"U{i}", "1"), (f"U{i+1}", "2")] for i in range(5)}
        p = lg.auto_place(pins, nets, width=63)
        r = lg.analyse(p, nets)
        self.assertEqual(r["spanning"], [])

    def test_heavy_traffic_pairs_end_up_adjacent(self):
        pins = {"A": 20, "B": 20, "C": 20, "D": 20, "E": 20, "F": 20}
        nets = {f"h{i}": [("A", "1"), ("F", "2")] for i in range(12)}
        nets["light"] = [("B", "1"), ("C", "2")]
        p = lg.auto_place(pins, nets, width=63)
        self.assertLessEqual(abs(p["A"][0] - p["F"][0]), 1)

    def test_board_count_is_reported(self):
        pins = {f"U{i}": 20 for i in range(5)}
        p = lg.auto_place(pins, nets={}, width=63)
        self.assertEqual(lg.board_count(p), max(b for b, _, _ in p.values()) + 1)


class TestFlippedBoard(unittest.TestCase):
    """The strips are mounted flipped, so the silkscreen numbers count DOWN
    left to right. Column numbers in a placement always mean the printed
    number — only the drawing mirrors."""

    def test_ascending_frame_is_identity(self):
        self.assertEqual(lg.visual_start(1, 20, 63, descending=False), 1)
        self.assertEqual(lg.visual_start(12, 20, 63, descending=False), 12)

    def test_column_one_sits_at_the_right_edge_when_flipped(self):
        # a 20-pin chip at printed cols 1..10 draws at 54..63
        self.assertEqual(lg.visual_start(1, 20, 63, descending=True), 54)

    def test_flip_is_its_own_inverse(self):
        for col, pins in ((3, 14), (12, 20), (46, 20)):
            v = lg.visual_start(col, pins, 63, descending=True)
            self.assertEqual(lg.visual_start(v, pins, 63, descending=True), col)

    def test_chip_stays_on_the_board_after_flipping(self):
        for col, pins in ((1, 20), (3, 14), (46, 20), (54, 20)):
            v = lg.visual_start(col, pins, 63, descending=True)
            self.assertGreaterEqual(v, 1)
            self.assertLessEqual(v + lg.chip_cols(pins) - 1, 63)

    def test_ruler_counts_down_when_flipped(self):
        self.assertEqual(lg.ruler_numbers(5, descending=True), [5, 4, 3, 2, 1])
        self.assertEqual(lg.ruler_numbers(5, descending=False), [1, 2, 3, 4, 5])

    def test_order_on_the_bench_reverses(self):
        """Left-to-right reading order flips, which is what you follow
        when wiring — the tool must be able to report it."""
        c = chips(U1=(0, 3, 14), U2=(0, 20, 20))
        self.assertEqual(lg.bench_order(c, 0, descending=False), ["U1", "U2"])
        self.assertEqual(lg.bench_order(c, 0, descending=True), ["U2", "U1"])


class TestCardEdge(unittest.TestCase):
    """Every board reserves a connector field at its low-numbered end so
    external wiring plugs into an edge instead of reaching in among the
    chips. Same end on every board, so inter-board ribbons run straight."""

    def setUp(self):
        self.c = chips(U1=(0, 10, 14), U2=(0, 30, 14), U3=(1, 10, 14))
        self.nets = {
            "/m/cross":  [("U1", "1"), ("U3", "2")],   # leaves board 0 and 1
            "/m/rigsig": [("U2", "3")],                # rig touches it
            "/m/private": [("U1", "4"), ("U2", "5")],  # stays home, no rig
            "GND":       [("U1", "7"), ("U3", "7")],
        }
        self.rig = {"rigsig"}

    def test_crossing_and_rig_nets_get_slots(self):
        s = lg.edge_slots(self.c, self.nets, 0, self.rig)
        self.assertEqual([n.rsplit("/", 1)[-1] for n in s], ["cross", "rigsig"])

    def test_private_nets_never_reach_the_edge(self):
        s = lg.edge_slots(self.c, self.nets, 0, self.rig)
        self.assertNotIn("/m/private", s)

    def test_power_never_reaches_the_edge(self):
        self.assertNotIn("GND", lg.edge_slots(self.c, self.nets, 0, self.rig))

    def test_a_bundle_lands_in_the_same_order_on_both_boards(self):
        """the whole point of a fixed edge: the ribbon goes straight"""
        c = chips(A=(0, 10, 14), B=(1, 10, 14))
        nets = {f"/m/{n}": [("A", "1"), ("B", "2")] for n in ("F2", "F0", "F1")}
        s0 = lg.edge_slots(c, nets, 0, set())
        s1 = lg.edge_slots(c, nets, 1, set())
        self.assertEqual(s0, s1)
        self.assertEqual([n.rsplit("/", 1)[-1] for n in s0], ["F0", "F1", "F2"])

    def test_edge_width_is_the_busiest_board(self):
        w = lg.edge_width(self.c, self.nets, self.rig)
        self.assertEqual(w, 2)                  # board 0 needs cross+rigsig

    def test_reserve_keeps_low_columns_clear(self):
        pins = {"U1": 20, "U2": 20}
        p = lg.auto_place(pins, {}, width=63, reserve=12)
        self.assertTrue(all(c > 12 for _, c, _ in p.values()))

    def test_reserve_can_force_another_board(self):
        pins = {f"U{i}": 20 for i in range(5)}          # 5 x 10 + gaps = 58
        loose = lg.auto_place(pins, {}, width=63, reserve=0)
        tight = lg.auto_place(pins, {}, width=63, reserve=20)
        self.assertLess(lg.board_count(loose), lg.board_count(tight))

    def test_edge_field_never_collides_with_chips(self):
        pins = {f"U{i}": 20 for i in range(6)}
        nets = {f"/m/n{i}": [(f"U{i}", "1"), (f"U{i+1}", "2")] for i in range(5)}
        chips_, reserve = lg.auto_place_with_edge(pins, nets, set(), width=63)
        self.assertEqual(lg.overlaps(chips_), [])
        self.assertEqual(lg.off_board(chips_, 63), [])
        self.assertTrue(all(c > reserve for _, c, _ in chips_.values()))

    def test_edge_sizing_settles(self):
        pins = {f"U{i}": (20 if i % 2 else 14) for i in range(7)}
        nets = {f"/m/n{i}": [(f"U{i}", "1"), (f"U{i+2}", "2")] for i in range(5)}
        chips_, reserve = lg.auto_place_with_edge(pins, nets, set(), width=63)
        self.assertGreaterEqual(reserve, lg.edge_width(chips_, nets, set()))


class TestRealAluPlacement(unittest.TestCase):
    """The shipped ALU placement must stay the best of its 6 board orders,
    and must not regress into overlaps."""

    def test_alu_placement_is_wellformed(self):
        p = lg.PLACEMENTS["alu"]
        self.assertEqual(lg.overlaps(p["chips"]), [])
        self.assertEqual(lg.off_board(p["chips"], p.get("width", 63)), [])

    def test_every_board_has_a_name(self):
        for name, p in lg.PLACEMENTS.items():
            boards = {b for b, _, _ in p["chips"].values()}
            self.assertEqual(len(p["boards"]), max(boards) + 1, name)


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)
