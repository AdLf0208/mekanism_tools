#!/usr/bin/env python3
"""Craft Mekanism: Tools' lapis recipes in a real crafting table.

The jar's own shaped recipes for lapis lazuli are the only ones whose
ingredient tag (`c:gems/lapis`) the port can fill (`minecraft:lapis_lazuli`),
so they are the recipes this slice can prove end to end:

    I I I        I = c:gems/lapis  (3)        -> mekanismtools:lapis_lazuli_pickaxe
     R           R = c:rods/wooden (stick, 2)
     R

    I I I        I = c:gems/lapis  (5)        -> mekanismtools:lapis_lazuli_helmet
    I   I

Called by tools/e2e.sh with the open game's control socket. Uses the harness's
crafting grid (`ctl screen`: slots 100-108 row-major, result 200). Asserts the
two real recipes and four controls that must stay empty:

  1. 3 lapis + 2 sticks -> 1 lapis_lazuli_pickaxe, and the stack reaches the
     inventory;
  2. 2 lapis + 2 sticks (one lapis short) -> empty;
  3. 3 diamonds + 2 sticks (wrong gem) -> empty;
  4. 3 lapis + 2 iron ingots in the rod cells (wrong tag member) -> empty;
  5. 5 lapis -> 1 lapis_lazuli_helmet;
  6. 9 lapis (the helmet's centre must stay empty) -> empty.

The table is replaced before every case, so nothing leaks between grids. Exits
1 with the observed result on the first mismatch.
"""
import json
import subprocess
import sys

# 3x3 grid: row-major slots 100..108, result 200.
PICK_HEAD = [100, 101, 102]
PICK_RODS = [104, 107]
HELMET = [100, 101, 102, 103, 105]
ALL_NINE = list(range(100, 109))


def main() -> None:
    sock, ctl, x, y, z = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

    def run(*args):
        out = subprocess.run([ctl, "--socket", sock, *args], text=True, capture_output=True)
        try:
            return json.loads(out.stdout)
        except json.JSONDecodeError:
            raise SystemExit(f"ctl {' '.join(args)}: {out.stdout}{out.stderr}")

    def wait(ticks=4):
        run("wait", str(ticks))

    def slots():
        screen = run("screen")
        if "slots" not in screen:
            raise SystemExit(f"no menu is open: {screen}")
        return screen["slots"]

    def find(item):
        for slot in slots():
            if slot.get("item") == item:
                return slot["slot"]
        raise SystemExit(f"missing ingredient {item} in the inventory")

    def open_table():
        wait()
        print("debug interact:", run("interact", x, y, z))
        wait(5)

    def result():
        stack = [s for s in slots() if s["slot"] == 200]
        if not stack or not stack[0].get("item"):
            return None
        return stack[0]

    def place(item, targets):
        slot = find(item)
        run("click-slot", str(slot))
        wait(1)
        for target in targets:
            # One item per cell: a right click splits the held stack.
            run("click-slot", str(target), "right")
            wait(1)
        run("click-slot", str(slot))
        wait(2)

    def setup(items):
        try:
            run("close")
        except SystemExit:
            pass
        wait(5)
        # A fresh table means a fresh crafting grid for every case.
        run("setblock", x, y, z, "minecraft:air")
        run("setblock", x, y, z, "minecraft:crafting_table")
        wait(2)
        print("debug tp:", run("command", f"tp @s {float(x) - 0.5} {y} {float(z) + 0.5}"))
        wait(3)
        run("command", "clear @s")
        for item, count in items:
            run("give", item, str(count))
        wait(3)
        open_table()

    failures = []

    def check(label, items, placements, want_item, want_count):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if not got or got.get("item") != want_item or got.get("count") != want_count:
            failures.append(f"{label}: expected {want_count} {want_item}, got {got}")
            return None
        return got

    def empty_control(label, items, placements):
        setup(items)
        for item, targets in placements:
            place(item, targets)
        got = result()
        print(f"{label} ->", json.dumps(got))
        if got is not None:
            failures.append(f"{label}: control crafted {got['item']} x{got['count']}")

    # 1. The real pickaxe recipe: 3 lapis + 2 sticks -> 1 lapis pickaxe.
    got = check(
        "3 lapis + 2 sticks",
        [("minecraft:lapis_lazuli", 3), ("minecraft:stick", 2)],
        [("minecraft:lapis_lazuli", PICK_HEAD), ("minecraft:stick", PICK_RODS)],
        "mekanismtools:lapis_lazuli_pickaxe",
        1,
    )
    if got:
        run("click-slot", "200")
        wait(5)
        run("click-slot", "9")
        wait(3)
        made = run("inventory")["counts"].get("mekanismtools:lapis_lazuli_pickaxe", 0)
        if made < 1:
            failures.append(f"the crafted lapis pickaxe reached the inventory as {made}, not 1")

    # 2. One lapis short: the pattern needs all three.
    empty_control(
        "2 lapis + 2 sticks",
        [("minecraft:lapis_lazuli", 2), ("minecraft:stick", 2)],
        [("minecraft:lapis_lazuli", PICK_HEAD[:2]), ("minecraft:stick", PICK_RODS)],
    )

    # 3. The wrong gem: `c:gems/lapis` holds lapis lazuli only.
    empty_control(
        "3 diamonds + 2 sticks",
        [("minecraft:diamond", 3), ("minecraft:stick", 2)],
        [("minecraft:diamond", PICK_HEAD), ("minecraft:stick", PICK_RODS)],
    )

    # 4. The wrong rod: `c:rods/wooden` holds sticks only.
    empty_control(
        "3 lapis + 2 iron ingots",
        [("minecraft:lapis_lazuli", 3), ("minecraft:iron_ingot", 2)],
        [("minecraft:lapis_lazuli", PICK_HEAD), ("minecraft:iron_ingot", PICK_RODS)],
    )

    # 5. The real helmet recipe: 5 lapis -> 1 lapis helmet.
    check(
        "5 lapis",
        [("minecraft:lapis_lazuli", 5)],
        [("minecraft:lapis_lazuli", HELMET)],
        "mekanismtools:lapis_lazuli_helmet",
        1,
    )

    # 6. Nine lapis: the helmet's centre cells must stay empty.
    empty_control(
        "9 lapis",
        [("minecraft:lapis_lazuli", 9)],
        [("minecraft:lapis_lazuli", ALL_NINE)],
    )

    run("close")
    wait(3)
    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "recipe PASS: 3 lapis + 2 sticks -> a lapis pickaxe (into the inventory) and "
        "5 lapis -> a lapis helmet; short-gem, wrong-gem, wrong-rod and all-nine "
        "controls stay empty"
    )


if __name__ == "__main__":
    main()
