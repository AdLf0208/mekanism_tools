# Mekanism Tools — a Horizon port

**Mekanism Tools** is a Minecraft mod. A mod for Minecraft. This repository is a **port of it to [Horizon](https://github.com/horizon-rust/horizon)**, the Rust engine for Minecraft Java 26.3. It carries the complete source of the port plus the content files it ships, and installs as a single `.hmod` package.

Upstream: [mekanism/Mekanism](https://github.com/mekanism/Mekanism) — licence **MIT**.

| | |
|---|---|
| Upstream mod | Mekanism Tools ([source](https://github.com/mekanism/Mekanism)) |
| Ported to | Horizon 0b14f8a, Minecraft Java 26.3, mod API `0.2` |
| Package | `mekanismtools.hmod` (install it with the Horizon launcher) |
| Licence | **MIT** — the upstream mod's licence; see [Licence and credit](#licence-and-credit) |

## What this port implements

- **72/72** items `/give`-able (two batches of 36);
- the creative tab `mekanismtools:all` lists exactly the 72 in generator order,
- **24/24** armour pieces equip by right-click into their own slot
- **attack differential**: `steel_sword` removes **6.888** hp from a zombie,
- `steel_pickaxe` breaks stone in **6 ticks**, drops cobblestone, and the held
- **paxel vs pickaxe on an oak log**: paxel **13 ticks** (axe rule), pickaxe
- item tags answer through `execute if items`: pickaxe in
- recipes: **3 lapis + 2 sticks → 1 lapis pickaxe** (and reaches the

## Not yet ported

- **Per-material stat numbers** (durability, speed, damage, armour,
- **The 55 recipes whose ingredient tag has no member** (`c:ingots/steel`,
- **Paxel crafting** (11 `mekanismtools:paxel` recipes) needs a custom recipe
- **Shields**: the mod's plate texture and the `mekanismtools:blocking`
- **Armour trims** (240 models) — a `minecraft:select` item definition per
- **Advancements** (6) and **translations** (80 lang files) are not carried.
- **Refined-glowstone piglin neutrality / refined-obsidian knockback
- **The parent mod's content** is still mostly unported: these tools cannot be

## Installing

1. Install the [Horizon launcher](https://github.com/horizon-rust/horizon/releases) (0.2.70 or newer).
2. Add `mekanismtools.hmod` to the instance's mods.
3. The package is pinned to a specific Horizon build; the launcher checks that pin.

## Licence and credit

Mekanism Tools was created by its upstream authors; the code, models and assets in the original mod
remain theirs and are used here under **MIT**. The Rust in this repository is a clean-room
rewrite for Horizon, not a translation of the original source.

- `LICENSE` — the upstream licence text.
- `LICENSE-NOTICE.md` — what this port carries and where it came from.
- The upstream project: https://github.com/mekanism/Mekanism

## Technical details

```
horizon-mod.toml   package manifest (id, version, api, [native] pin)
Cargo.toml         the crate; depends on `horizon-mod-api` from the fetched SDK
src/               lib.rs (the one `impl Hooks`), runtime.rs (pure logic + tests), glue
assets/ data/      the content the package ships
tools/             content generators and the e2e scenario
```

- Build: `cargo horizon-mod build` (packages; it does not compile against the game).
- Test: `cargo test`, `cargo clippy --all-targets -- -D warnings`.
- In-game: `ports/tools/launcher-game.sh run mekanismtools` in the campaign tree, or install the
  `.hmod` and play; the harness scenario is `tools/e2e.sh`.

This repository is generated from the campaign's port at `ports/mekanismtools/`; the port's own
`notes.md` is the full record (decisions, traps, evidence).
