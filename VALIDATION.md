# VALIDATION — Mekanism: Tools slice 1

> **HISTORICAL (0.1.0).** Everything below was measured for the retired `.hnmod`
> bundle at pin `1d63e0a5` / mixins `5a64af93`, and it stays as the behaviour's
> evidence: the scenarios, the numbers and the assertions are unchanged. The
> 0.2.0 SDK package (`api = "0.2"`, pin `0b14f8ac` / mixins `e59da909`) is
> verified by the ladder and the package checks in `notes.md`, "Migration to the
> SDK format"; no in-game run exists for it in this environment because
> `horizon-launcher` is not installed here.

Pin **Horizon `1d63e0a5a37a7a708eb0b32b49bf0dfeb28ed8a9`** (`game.rs`
`64813cf4db0b9c3983d42908609bb633b9fbbc705f0c890396f940a6c7cef80f`),
**horizon-mixins `5a64af938ec86b00d53d16a408aabc0038fb3e57`** (schema 6).
Everything below ran on 2026-11-09/10 through `ports/tools/build-slot.sh`
(`CARGO_INCREMENTAL=0`, no bare `cargo`, no `--target-dir`), with
`--horizon ports/_shared/pins/horizon-1d63e0a`. Logs:
`ports/_shared/evidence/mekanismtools/`.

## Standalone census crate (test-only module, no injection)

| Check | Command | Result |
|---|---|---|
| fmt | `cargo fmt --all -- --check` | exit 0 (`fmt.log`) |
| tests | `cargo test --locked --offline` | **8 passed, 0 failed** (`runtime.log`) |
| clippy | `cargo clippy --all-targets --locked --offline -- -D warnings` | exit 0, **0 warnings** (`clippy.log`) |

## Content ↔ jar

| Check | Command | Result |
|---|---|---|
| generator | `python3 tools/gen_content.py --check` | `content tree matches the jar census` |
| Rust census | (same run) | `Rust census: 72 item ids match the jar` |
| counts | (same run) | `{"armour":24,"equipment":6,"items":72,"models":66,"paxels":12,"recipes":65,"shields":6,"skipped_recipes":22,"textures":66,"tool_items":30,"trim_models_skipped":240}` |

## Staged ladder at `1d63e0a`

| Step | Command | Result |
|---|---|---|
| stage | `python3 tools/horizon.py stage --horizon …/pins/horizon-1d63e0a` | exit 0, 92 s (`stage.log`) |
| check | `python3 tools/horizon.py check --horizon …` | `cargo_exit: 0`, **0 warnings** (`horizon-check.log`, `horizon-check-cargo.log`) |
| test | `python3 tools/horizon.py test --horizon …` | `cargo_exit: 0`, `test result: ok. **8 passed**; 0 failed; 1240 filtered out` (`horizon-test.log`, `horizon-test-cargo.log`) |

The test filter in `tools/horizon.py` was adjusted from the scaffold's
`game::factory_blocks::tests` to `game::mekanismtools::tests`; the first run
showed `0 passed; 1248 filtered` and the fix is proven by the 8 embedded tests
running as `game::mekanismtools::tests`.

## Content package

| Check | Command | Result |
|---|---|---|
| build | `cargo-horizon-mod build` in `content/` | exit 0, `Built ./target/horizon-mod/mekanismtools.hmod` (`hmod-build.log`) |
| check | `cargo-horizon-mod check content/mekanismtools.hmod --json` | `{"ok":true,"report":{"api":"0.2","capabilities":["registries"],"id":"mekanismtools","kind":"mod","sha256":"53c7e40e…","side":"both","signed":false,"size":166572,"version":"10.7.19"}}` (`hmod-check.json`) |
| reproducible | rebuild + `sha256sum` | delivered = rebuilt = `53c7e40e52459f542b96cf0587d837cbac822cfbacdc20f6f249aedf43fa7caa` |

Delivered: `content/mekanismtools.hmod`, **166,572 B**, SHA-256
`53c7e40e52459f542b96cf0587d837cbac822cfbacdc20f6f249aedf43fa7caa`, **394
archive entries**, unsigned, API 0.2, `side = both`, capabilities `registries`.

## In-game runs (shared unmodded `1d63e0a5` game, `--dev-mod content/`)

| Run | Command | Result |
|---|---|---|
| default | `build-slot.sh run … -- tools/e2e.sh` | **PASS, `EXIT:0`** — `e2e-default.log` |
| selftest | `SELFTEST=1 tools/e2e.sh` | **FAIL, `EXIT:1` as required** — `e2e-selftest.log` |
| `.hmod` load | `tools/hmod-load.sh` | **PASS, `EXIT:0`** with the no-`--dev-mod` control — `hmod-load.log` |
| log checker | `python3 ports/tools/check-e2e-logs.py mekanismtools --strict` | `logs=2 ok=2 missing-exit=0 bad-exit=0`, exit 0 |

Default run, quoted from `e2e-default.log`:

```
  dimension after the teleport: minecraft:the_end
  arena: floor(0,79,0)=minecraft:stone summon-cell(0,80,0)=minecraft:air
72/72 items are give-able
creative tab mekanismtools:all lists all 72 items in order
  bronze_helmet -> head          ... (24 lines, one per armour piece)
24/24 armour pieces equip into their own slot
  mekanismtools:steel_sword -> {"hit":true,"target":250,"health_before":20.0,"health":13.11...,"alive":true}
  minecraft:stick          -> {"hit":true,"target":255,"health_before":20.0,"health":19.05...,"alive":true}
  damage: steel_sword 6.888, stick 0.940
  pickaxe on stone: {"block_before":"minecraft:stone","block":"minecraft:air","drops":{"minecraft:cobblestone":1},"ticks":6}
  held damage after one block: 1
  paxel on a log: {"block_before":"minecraft:oak_log[axis=y]","block":"minecraft:air","drops":{"minecraft:oak_log":1},"ticks":13}
  pickaxe on a log: {"block":"minecraft:oak_log[axis=y]","error":"timed out before the block broke","ticks":16}
  the pickaxe left the log standing in the same 16-tick budget
  paxel on dirt: {"block":"minecraft:air","drops":{"minecraft:dirt":1},"ticks":2}
tags: pickaxe in #minecraft:pickaxes, sword in #minecraft:swords, helmet in #minecraft:head_armor, pickaxe not in swords
3 lapis + 2 sticks -> {"count": 1, "item": "mekanismtools:lapis_lazuli_pickaxe", "slot": 200}
2 lapis with a gap + 2 sticks -> null
3 coal + 2 sticks -> null
3 lapis + 2 iron ingots -> null
5 lapis -> {"count": 1, "item": "mekanismtools:lapis_lazuli_helmet", "slot": 200}
5 lapis, shifted one cell right -> null
recipe PASS: 3 lapis + 2 sticks -> a lapis pickaxe ... 5 lapis -> a lapis helmet ...
unknown mekanismtools ids are refused
PASS: 72/72 items give, the creative tab lists all 72, 24/24 armour pieces equip into their own slot, the steel sword out-damages a stick, the pickaxe breaks stone and wears by 1, the paxel breaks a log while the pickaxe times out and breaks dirt in 8 ticks, the item tags answer, the lapis recipes craft with four empty controls, and unknown ids are refused
EXIT:0
```

Fail-capability (`e2e-selftest.log`), quoted:

```
+ SELFTEST: a deliberately false equip assertion must fail the run
FAIL: SELFTEST: the chest slot reads 'empty' after a stick, not the deliberately wrong 'mekanismtools:steel_chestplate'; the equip read-back is live (this exit 1 is the proof)
EXIT:1
```

`.hmod` negative control (`hmod-load.log`), quoted:

```
item mekanismtools:steel_pickaxe = 1
head slot = mekanismtools:lapis_lazuli_helmet
  paxel on a log: {"block":"minecraft:air","drops":{"minecraft:oak_log":1},"ticks":7}
== negative control: the SAME ids without --dev-mod ==
control item mekanismtools:steel_pickaxe = 0
control item mekanismtools:lapis_lazuli_helmet = 0
control item mekanismtools:netherite_paxel = 0
control item mekanismtools:bronze_shield = 0
control: all four ids are unknown without the package
PASS: the .hmod registers the four sampled items, its helmet equips and its paxel breaks a log; without it the same ids are refused
EXIT:0
```

## Harness findings worth keeping

- **A summon cell that is not air poisons every health reading**: a `NoAI`
  zombie spawned into a solid block loses 1 hp per ~10 ticks (suffocation), so
  the first attempt measured "sword 2 vs stick 2". The e2e now builds the arena
  with `execute in minecraft:the_end run fill …` and **verifies**
  `floor(0,79,0)=stone` and `cell(0,80,0)=air` before any test.
- **Killing the ender dragon opens the win screen**, which silently swallows
  every click (`use-item` answers *"the win screen is open"*). The harness now
  **freezes** the dragon (`NoAI:1b,Silent:1b`), moves it 4 km away and fails the
  run if one is within 64 blocks — so the exit portal never spawns — and every
  input phase goes through `ensure_playing`, which names and closes a stray
  screen before clicking (see `notes.md` §"Harness fix: the win screen").
- **The client's mob health syncs ~10 ticks after a hit**, not the 4 the attack
  reply waits, so the e2e reads the target's health from `ctl entities` before
  and after the swing instead of trusting the reply's `health`.
- **`ctl break <timeout>` reports the state string in `block` when it times
  out** (`minecraft:oak_log[axis=y]`), so a timeout is detected on
  `.error == "timed out before the block broke"`.
- **Vanilla recipes collide with naive controls**: 9 lapis crafts a lapis block,
  3 diamonds + 2 sticks a diamond pickaxe, 2 contiguous lapis + 2 sticks a hoe.
  The four controls now use patterns vanilla has no recipe for.

## Re-run, 2026-11-11 (stale-artifact job)

`upstream_ready.py` blocked the port because the delivered `.hmod` was **older
than its sources** (mtime 2026-11-09 12:11 < 2026-11-10 05:04). The artifact
was re-derived from the current tree and every gate re-run; nothing in
`content/` changed, so the bytes are unchanged.

| Step | Command | Result |
|---|---|---|
| fmt | `tools/unit.sh` in a slot | `fmt_exit=0` |
| tests | (same) | `test result: ok. **8 passed**; 0 failed` |
| clippy | (same) | `clippy_exit=0`, `warning_lines=0` |
| content ↔ jar | (same) | `content tree matches the jar census`; `Rust census: 72 item ids match the jar` |
| package (1) | `rm -rf content/target/horizon-mod; cargo-horizon-mod build` | `Built ./target/horizon-mod/mekanismtools.hmod`, `53c7e40e…faa` |
| package (2) | same, clean again | `53c7e40e…faa` — **reproducible**, `check --json` `{"ok":true,…}` |
| stage | `tools/horizon.py stage --horizon …/horizon-1d63e0a` | exit 0, `stage_changed: true` |
| check | `tools/horizon.py check` | `cargo_exit: 0`, 0 warning lines |
| embedded test | `tools/horizon.py test` | `cargo_exit: 0`, `8 passed; 0 failed; 1240 filtered` |
| e2e default | `build-slot.sh e2e … -- tools/e2e.sh` | **PASS, `EXIT:0`** (`e2e-default.log`) |
| e2e selftest | `SELFTEST=1 build-slot.sh e2e …` | **FAIL, `EXIT:1`**, verdict line present (`e2e-selftest.log`) |
| `.hmod` load | `build-slot.sh run --step e2e -- tools/hmod-load.sh` | **PASS, `EXIT:0`**, four ids unknown in the no-`--dev-mod` control (`hmod-load.log`) |
| log checker | `check-e2e-logs.py mekanismtools --strict` | `logs=2 ok=2 missing-exit=0 bad-exit=0`, exit 0 |
| publish gate | `upstream_ready.py mekanismtools` | **only** the parent blocker remains (mekanism not in the registry) |

Note: an early `build-slot.sh run` in this job was **forwarded** to the second
machine and its `pull_port` (rsync without `--delete`, quick-check on size)
brought that box's older `e2e-*.log` copies back over the local ones; the legs
above were then re-run locally (`BUILD_LOCAL=1`, and the e2e script keeps itself
local because it runs the shared game binary), so every log in this table is
from this run.
