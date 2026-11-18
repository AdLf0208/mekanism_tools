# Mekanism: Tools — port notes (slice 1: the 72 items, data tier)

Ported from **Mekanism: Tools 10.7.19.85** (`mekanism/Mekanism`, **MIT**), the
exact ATM10 jar `MekanismTools-1.21.1-10.7.19.85.jar` (size 526,620 B, SHA-1
`4433b3eec0a5a0bf415d873e710a1cecea5850bc` = the Modrinth `10.7.19.85` file and
the pack's `licence-precheck.csv` row; provenance, hashes and what the jar
registers in [`carry-work/SOURCE.md`](../_shared/carry-work/mekanismtools/SOURCE.md)).

**LOCAL-ONLY** until the maintainer approves publishing (ARCHITECTURE.md §8).
MIT is licence rank 0 (permissive); the approval is still required.

Pin **Horizon `1d63e0a5a37a7a708eb0b32b49bf0dfeb28ed8a9`** (`game.rs`
`64813cf4…f80f`), **horizon-mixins `5a64af938ec86b00d53d16a408aabc0038fb3e57`**
(schema 6).

Status: **ported** — a content-only `.hmod` carrying all **72 items** the jar
registers, verified in-game (register, equip, attack, mine, craft, tags,
unknown ids), with the no-`--dev-mod` negative control on the delivered package.

**Format 0.2.0 (2026-11-18):** the delivered unit is now one flat SDK package
(`horizon-mod.toml` with `api = "0.2"`, the content at the package root and one
`impl Hooks` in `src/lib.rs`). The in-game evidence below is the 0.1.0 `.hnmod`
bundle's; see `## Migration to the SDK format` for what changed, the package
facts and the missing 0.2.0 in-game run.

## Class + tier, approach, licence

- **Class `content`, tier `data`** (`ports/ledger.csv`, from
  `ports/_shared/source-map/atm10-sources.csv`), **add-on** of `mekanism`
  (parent `ported-partial`; the jar requires `mekanism [10.7.19]`).
- **Approach: carry-over** (`horizon/docs/modpacks.md` §Tiers/§4). A data-tier
  mod ships assets/data and registry declarations, **no behaviour code**:
  - the 72 items are declared in `data/mekanismtools/horizon/item/*.json` from
    **26.3 vanilla item templates**;
  - the jar's own models, textures, lang, recipes and tags are carried into
    their 26.3 formats;
  - `mixins/mekanismtools/runtime.rs` is a **test-only census** (zero
    `[[injection]]`s): it pins the families, the template map, the harvest tiers,
    the armour equipment ids and the paxel rule shape the generator writes. A
    data-tier port needs no hook, and this pin warns `dead_code` for a module
    with no injection, so the module lives under `#[cfg(test)]` (AGENT_MOD_
    STRUCTURE.md §4).
- **Why now:** licence-first queue — MIT (rank 0), `content`/`data`, an
  add-on whose parent is already `ported-partial`, and a mechanical carry with
  a real in-game oracle. `precheck-mod.py mekanismtools` → dispatchable, jar
  licence MIT (rank 0).

## Slice boundary (what this slice is, and is not)

**In:** every item of the jar — 6 materials × 7 tool kinds, 6 materials × 4
armour slots, the 6 vanilla paxels — their models, item definitions, textures,
armour equipment layers, lang, the 65 recipes that can load, and the item tags.
**Out:** the mod's Java behaviour (the client half), per-material stat numbers,
trim overlays, the shield's custom renderer and its blocking property, the two
custom recipe types, the advancements and the translations. Gaps below.

## Template map (each choice has evidence)

Tool tier = the jar's own block tag `data/mekanismtools/tags/block/
incorrect_for_<material>_tool.json` (FINDINGS §2); armour class = the nearest
documented defence total (FINDINGS §3, project wiki "Armor"); paxel = the
material's pickaxe template plus the axe/shovel rules.

| Material | Tool template | Armour template | Documented armour (defence/toughness) → vanilla |
|---|---|---|---|
| `bronze` | `iron` | `diamond` | 18/4 → diamond 20/8 |
| `lapis_lazuli` | `stone` | `golden` | 9/0 → gold 11/0 |
| `osmium` | `iron` | `diamond` | 21/12 → diamond 20/8 |
| `refined_glowstone` | `diamond` | `diamond` | 20/0 → diamond 20/8 |
| `refined_obsidian` | `netherite` | `netherite` | 30/20 → netherite 20/12 |
| `steel` | `diamond` | `diamond` | 20/8 → diamond 20/8 (exact) |

Vanilla paxels use their own material (`wooden`, `stone`, `iron`, `golden`,
`diamond`, `netherite` templates).

**Deviations this mapping accepts (recorded, not hidden):**

1. **Durability, mining speed, attack damage, armour points, toughness and
   enchantability are the template's, not the mod's.** Upstream's numbers live
   in its Java material classes; §3 of ARCHITECTURE.md already rules that tool
   stats are read from the **item** here (`items.rs:1135`, `:1156`) and the
   faithful per-stack `break_speed` hook is pending. Because every item id has
   fixed stats, a later slice *can* stamp the documented figures as components
   (`minecraft:max_damage`, `minecraft:tool`, `minecraft:attribute_modifiers`);
   this slice deliberately does not, because the jar carries no data for them
   and the wiki is an older version's table. The known deltas:
   lapis armour +2 defence; bronze armour +2 defence/+4 toughness; osmium
   armour −1 defence/−4 toughness; glowstone +8 toughness; obsidian −10
   defence/−8 toughness; tool durability/speed per FINDINGS §3.
2. **No piglin-neutral or knockback-resistance behaviour is reproduced.** Upstream
   gives refined-glowstone armour piglin neutrality and refined-obsidian armour
   knockback resistance; netherite's template brings 40 % knockback resistance
   and fire-resistant items to refined obsidian only.
3. **A paxel's attack damage is its pickaxe template's**, not upstream's
   (between a sword and an axe). Its *mining* is faithful: the `minecraft:tool`
   rule union covers pickaxe + axe + shovel at the template's speed, and
   `minecraft:block_transformer: minecraft:axe` gives the axe's right-click
   actions.
4. **Armour worn layers are the mod's own** (`assets/mekanismtools/equipment/
   <material>.json` + `textures/entity/equipment/{humanoid,humanoid_leggings}/
   <material>.png`, mapped from `textures/models/armor/<material>_layer_{1,2}.png`),
   but with no trim overlay.
5. **Shields render as vanilla shields.** Their plate texture and blocking model
   need `RenderMekanismShieldItem` and a custom item-model property.

## Carried vs skipped (from the jar)

| Carried | Count |
|---|---|
| item declarations (`data/mekanismtools/horizon/item/*.json`) | 72 |
| creative tab (`creative_tab/all.json`) | 1 |
| 26.3 item definitions (`assets/mekanismtools/items/*.json`) | 72 (66 plain + 6 vanilla shield definitions) |
| item models (`models/item/*.json`, `overrides` dropped) | 66 |
| textures (`textures/item/**`) | 66 |
| armour equipment assets + layers | 6 + 12 textures |
| lang (`en_us.json`, 800 keys) | 1 |
| recipes | 65 (60 shaped, 4 vanilla-nugget cooking, 1 netherite smithing) |
| item tags | `minecraft` 18 files, `c` 6 files (incl. `c:block/mineable/paxel`), `mekanismtools` block gates 6 files |
| hand-written convention tags | `c:rods/wooden` → `minecraft:stick`, `c:gems/lapis` → `minecraft:lapis_lazuli` |

| Skipped | Why |
|---|---|
| 11 `mekanismtools:paxel` recipes | custom recipe type no vanilla reader knows (paxels come by `/give`; the netherite paxel keeps its vanilla smithing transform) |
| 1 `mekanismtools:banner_shield` recipe | custom type |
| 10 `mekanism:nugget_*` smelting/blasting recipes | the result item does not exist in the parent port yet (the gold/iron nugget ones **are** carried: vanilla results) |
| 240 `*_trim` armour models | their `layer1` textures do not exist in 26.3 (a single `*_trim.png` per piece now) |
| 6 `*_shield_blocking` models, `entity/shield/*.png`, `atlases/shield_patterns.json` | need the client half; the atlas file is `minecraft`-namespace |
| 6 advancements, 80 non-English lang files, `logo.png`, `pack.mcmeta` | not needed by the slice |
| no loot tables exist | the mod adds no blocks |

## Hooks

**None.** Zero `[[injection]]`s — this is the data shape. The bundle is the pure
census module with its 8 tests (see `mixins/mekanismtools/horizon-mixin.toml`).

## Behaviour verified in-game (fail-capable)

The e2e (`tools/e2e.sh`) on the shared unmodded `1d63e0a5` game with
`--dev-mod content/`, The End arena, y=80. The dragon is **frozen, not killed**
(the win-screen fix below), and every input phase asserts
`state.screen == "playing"` before it clicks.

1. **72/72** items `/give`-able (two batches of 36);
2. the creative tab `mekanismtools:all` lists exactly the 72 in generator order,
   and no undeclared `mekanismtools:` id is in any tab;
3. **24/24** armour pieces equip by right-click into their own slot
   (head/chest/legs/feet) and read back from `ctl inventory`;
4. **attack differential**: `steel_sword` removes **6.888** hp from a zombie,
   `minecraft:stick` **0.940** (the sword's `minecraft:attribute_modifiers` +
   weapon component are applied; the stick is the control);
5. `steel_pickaxe` breaks stone in **6 ticks**, drops cobblestone, and the held
   stack wears **exactly 1**;
6. **paxel vs pickaxe on an oak log**: paxel **13 ticks** (axe rule), pickaxe
   **times out at 16 ticks** with the log still standing (the differential);
   paxel breaks dirt in **2 ticks** (shovel rule);
7. item tags answer through `execute if items`: pickaxe in
   `#minecraft:pickaxes`, sword in `#minecraft:swords`, helmet in
   `#minecraft:head_armor`, and the pickaxe is *not* in `#minecraft:swords`;
8. recipes: **3 lapis + 2 sticks → 1 lapis pickaxe** (and reaches the
   inventory), **5 lapis → 1 lapis helmet**, with four empty controls
   (2 lapis with a gap, 3 coal, 3 lapis + 2 iron ingots, the helmet window
   shifted one cell);
9. unknown ids refused (`mekanismtools:not_a_tool`, `mekanismtools:steel_paxel_extra`).

### Harness fix: the win screen (2026-11-10)

The first default leg failed on the very first armour equip:

```
FAIL: use-item failed for mekanismtools:bronze_helmet:
  {"error":"the win screen is open; close it first (close, or click-button)"}
```

Cause: the harness killed the ender dragon during arena setup, which arms the
exit portal. The only thing that opens the WinScreen in a game (besides
`ctl credits`) is the `WIN_GAME` event, which the server sends to a player inside
an End exit portal — and that screen (poem/credits) swallows every click.
Closing it is not a fix either: `WinScreen.onFinished` sends `PERFORM_RESPAWN`,
so the player is respawned in the Overworld and the arena is gone.

The harness now removes the cause and guards every input:

1. `launch` no longer kills the dragon. It freezes it
   (`data merge entity @e[type=ender_dragon,limit=1] {NoAI:1b,Silent:1b}`) and
   moves it 4 km away (`tp … 4096 128 4096`), then **fails** the run if a dragon
   is still within 64 blocks. The exit portal — and so the win screen — is never
   spawned, and the dragon cannot attack the survival phases
   (`ender dragons within 64 blocks after the neutralisation: []` in the log).
2. `ensure_playing` runs before every input phase, before each of the 24
   `use-item` equips and before the selftest equip. It names the open screen
   (`ctl state` / `ctl screen`), closes it (`ctl close`; `ctl respawn` for the
   death screen) up to three times, and hard-fails naming the screen if it will
   not close. Because a closed WinScreen respawns the player, a close that
   moved them puts them back at the End arena and re-verifies the floor at
   `0,79,0`.
3. `assert_playing` is a hard error on any open screen, so a regression reads
   "a 'win' screen is open before the equip of mekanismtools:bronze_helmet",
   never a silent `use-item` failure.

The older `VALIDATION.md` note that the harness "kills the dragon, then
`ctl close`" is superseded by this fix. Evidence: `e2e-default.log`
(2026-11-10, PASS + `EXIT:0`) and `e2e-selftest.log` (FAIL + `EXIT:1`).

Negative control on the delivered package (`tools/hmod-load.sh`): the `.hmod`
registers the four sampled items, its helmet equips and its paxel breaks a log;
**the same world without `--dev-mod` refuses all four ids** and wears nothing.

Skills: superpowers/using-superpowers,writing-plans,systematic-debugging,verification-before-completion; BeautifulRust/none (no Rust change: the 2026-11-11 rebuild only re-ran the package build, the ladder and the e2e legs)

## Verification

Pin **`1d63e0a5a37a7a708eb0b32b49bf0dfeb28ed8a9`**, mixins
**`5a64af938ec86b00d53d16a408aabc0038fb3e57`** (schema 6). Every step ran
through `ports/tools/build-slot.sh` (`CARGO_INCREMENTAL=0`, no bare `cargo`, no
`--target-dir`); the e2e/hmod legs used the pin-matched shared binaries
(`ports/_shared/bin/horizon-1d63e0a5/`). Logs:
[`ports/_shared/evidence/mekanismtools/`](../_shared/evidence/mekanismtools/).

| Step | Command (through the slot runner) | Result |
|---|---|---|
| content ↔ jar | `python3 tools/gen_content.py --check` | `content tree matches the jar census`; `Rust census: 72 item ids match the jar` |
| fmt | `cargo fmt --all -- --check` | exit 0 (`fmt.log`) |
| runtime tests | `cargo test --locked --offline` | **8 passed**, 0 failed (`runtime.log`) |
| runtime lints | `cargo clippy --all-targets --locked --offline -- -D warnings` | exit 0, **0 warnings** (`clippy.log`) |
| stage | `tools/horizon.py stage --horizon …/horizon-1d63e0a` | exit 0, 92 s (`stage.log`) |
| check | `tools/horizon.py check` | `cargo_exit: 0`, **0 warnings** (`horizon-check-cargo.log`) |
| embedded test | `tools/horizon.py test` | `test result: ok. **8 passed**; 0 failed; 1240 filtered` (`horizon-test-cargo.log`) |
| content package | `cargo-horizon-mod build` in `content/` | exit 0, **166,572 B**, 394 entries, `horizon-mod check` `{"ok":true,…}` (`hmod-build.log`, `hmod-check.json`) |
| reproducible | two clean rebuilds + `sha256sum` (2026-11-11) | **both = the delivered** `53c7e40e…faa` |
| e2e default | `build-slot.sh e2e … -- tools/e2e.sh` | **PASS, `EXIT:0`**, runner `exit 0` (`e2e-default.log`) |
| e2e selftest | `SELFTEST=1 build-slot.sh e2e …` | **FAIL, `EXIT:1`** as required (`e2e-selftest.log`) |
| `.hmod` load | `build-slot.sh run --step e2e -- tools/hmod-load.sh` | **PASS, `EXIT:0`** with the no-`--dev-mod` control (`hmod-load.log`) |
| log checker | `check-e2e-logs.py mekanismtools --strict` | `logs=2 ok=2 missing-exit=0 bad-exit=0`, exit 0 |

### Rebuild 2026-11-11 (stale-artifact job)

`upstream_ready.py` reported *“artifact older than the port's sources — rebuild
it (2026-11-09 12:11 < 2026-11-10 05:04)”*. The comparison is by mtime, and the
content bytes had not changed since the first build, so this job re-derived the
package and proved it rather than editing anything:

- two clean builds (`rm -rf content/target/horizon-mod` before each, through the
  slot runner, `CARGO_INCREMENTAL=0`) both produce **166,572 B / 394 entries /
  `53c7e40e52459f542b96cf0587d837cbac822cfbacdc20f6f249aedf43fa7caa`** — the
  delivered file was already correct and is now copied from this run
  (`hmod-build.log`), with `cargo-horizon-mod check --json` `{"ok":true,…}`;
- `cargo-horizon-mod build` is the port's only packaging step; the census crate
  is test-only and has no `[[injection]]`, so there is **no `.hnmod`** to rebuild
  (a data-tier port ships the `.hmod`; the code bundle arrives with a later
  slice that needs behaviour);
- the publish tree (`ports/_shared/horizon-mods/publish/mekanismtools/`) is
  byte-identical to `content/` and its `registry.toml` already names
  `53c7e40e…`, so **no sha refresh was needed**; its description still carries
  the old "steel sword deals the same damage as a stick / do not publish"
  paragraph and is the orchestrator's to update before submission;
- `upstream_ready.py mekanismtools` now reports **only** the parent blocker
  (“add-on whose required parent(s) __manual__, mekanism are not in the
  registry”) — the stale-artifact reason is gone.

### Deliverables

| File | Size | SHA-256 | Entries |
|---|---:|---|---:|
| `content/mekanismtools.hmod` | 166,572 B | `53c7e40e52459f542b96cf0587d837cbac822cfbacdc20f6f249aedf43fa7caa` | 394 |

The `.hnmod` is **not** shipped: this is a data-tier port with no injection, and
the census module exists to make the content testable (`cargo test`), not to add
behaviour. When a later slice needs code (the client half for shield plate
textures, or stamped per-material stats), it ships `mekanismtools.hnmod` beside
`content/` — one file per registry project means it cannot ship both today.

## Gaps (next slices)

1. **Per-material stat numbers** (durability, speed, damage, armour,
   enchantability) — see deviation 1; needs the documented table stamped as
   components, and an in-game check per family.
2. **The 55 recipes whose ingredient tag has no member** (`c:ingots/steel`,
   `bronze`, `osmium`, `refined_glowstone`, `refined_obsidian`): they load with
   an empty ingredient and never match until the parent port registers those
   ingots (mekanism gap 6). Lapis recipes craft today (the two `c:` tags are
   written by hand).
3. **Paxel crafting** (11 `mekanismtools:paxel` recipes) needs a custom recipe
   type; today paxels come by `/give`.
4. **Shields**: the mod's plate texture and the `mekanismtools:blocking`
   item-model property need the client half (`RenderMekanismShieldItem`), and
   the banner-on-shield recipe type is likewise unported.
5. **Armour trims** (240 models) — a `minecraft:select` item definition per
   piece once the 26.3 palette scheme is confirmed.
6. **Advancements** (6) and **translations** (80 lang files) are not carried.
7. **Refined-glowstone piglin neutrality / refined-obsidian knockback
   resistance** are upstream code behaviour, not data (deviation 2).
8. **The parent mod's content** is still mostly unported: these tools cannot be
   crafted from Mekanism ingots until mekanism's ore-processing chain exists.

## Provenance (upstream analysis)

No repository clone was read for this slice: the jar carries the whole data
half, every behaviour claim is a 26.3 vanilla template or a public wiki figure,
and no Java was opened (the class files were counted, never parsed). Public
sources used and recorded in [`FINDINGS.md`](FINDINGS.md) §3:
`https://wiki.aidancbrady.com/wiki/Armor` (defence/toughness per set) and the
per-set pages (`Osmium_Armor`, `Lapis_Lazuli_Armor`, `Steel_Armor`,
`Refined_Obsidian_Armor`, `Bronze_Armor`, `Glowstone_Armor`) for per-slot
durability. Licence evidence: the jar's `META-INF/neoforge.mods.toml`, the
Modrinth version `10.7.19.85` file hash, and the pack's `modlist.json` entry.

## Reviewer repairs (2026-11-11) — PR review items and what changed


Each item below is quoted from `ports/_shared/horizon-mods/reviews/pr-*-mekanismtools.md` (the review is the specification), with what this repair did about it.

- **Reviewer:** [P1] MIT notice not in the bundle
  **Repair:** The content build now carries `data/mekanismtools/license/{license,notice}.txt` (`tools/stamp_license.py`, called by the packaging step), so the downloaded `.hmod` holds the notice and the original copyright.
- **Reviewer:** [P2] missing survival paxel recipes
  **Repair:** Disclosed in the description: the eleven non-netherite paxels have no recipe (`tools/gen_content.py` drops them) and the netherite paxel needs the diamond one, so they are creative/give only.
- **Reviewer:** parent requirement not disclosed
  **Repair:** The description now names Mekanism as required, says 55 of the 65 recipes need it (10 work standalone) and keeps the merge-order note.
- **Reviewer:** registry artifact delivery
  **Repair:** **Staging (orchestrator, not ours)**: the artifact is not in registry release/staging as `<sha256>.<ext>`; the orchestrator answers it with `horizon-mods#686` (no write access to the registry's releases). Every repackaged artifact below has a fresh sha256 for that re-push, and the author release must be re-uploaded from the port repository.

Skills: superpowers/using-superpowers,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices

## Migration to the SDK format (0.2.0, 2026-11-18)

Horizon's mod-API merge (#16941, launcher ≥ 0.2.70, PR #17992) retired `.hnmod`: the registry
closed every `.hnmod` submission on 2026-11-18 with one reason, and an `.hnmod` no longer loads.
The unit is now **one flat `.hmod`** — content, native code, or both. This port is the **data-tier**
case of that migration: its written evidence was already data (`assets/`, `data/`), its retired
bundle had no injection, and the only code it owns is a test-only census.

Pins for this migration: nightly **`0b14f8acfd97fa2c750e42795249dcc981178ca4`** (2026-11-18,
`package_format` 6, `content_api` "0.2"), mixins **`e59da9094f0c2fdda6c627fe9eff22dec6a906f0`**,
launcher 0.2.78, `cargo-horizon-mod` from `horizon-rust/horizon@main` (`448cd693`). The SDK is
cached in-tree at `../_shared/sdk/0b14f8a/` and copied into `.horizon/sdk/` (gitignored) for
offline builds. Reference recipes: `imfast` (the original twelve steps), `enderstorage`,
`naturesaura` and — same family — `mekanismgenerators`, the first content+code migration.

**This is a first publication.** The 0.1.0 `.hnmod` content bundle was reviewed in PR #673
(changes requested, never merged), so no published version is superseded; the changelog says so
below. Licence unchanged: **MIT**, rank 0, read from the jar
(`META-INF/neoforge.mods.toml`, `licence-precheck.csv` row
`mekanismtools,True,True,MIT,MIT,MekanismTools-1.21.1-10.7.19.85.jar,MIT,,MIT,0,permissive,True,`), and
**local-only until the maintainer approves publishing** — the migration changes the format, not
that ruling.

### The line that makes this a migration and not a rewrite

`src/runtime.rs` is `mixins/mekanismtools/runtime.rs` **byte-identical**: `cp`, then `cmp` exit 0,
SHA-256 `e355bad90d3131700599d631c7c0bd944fd2fda46bc611baef62eaad298a49ea` on the retired file, on
`src/runtime.rs` and on the packaged entry (`unzip -p mekanismtools.hmod src/runtime.rs`;
`evidence/mekanismtools/sdk-runtime-sha256.txt`). Its **8 tests were green before any glue
existed** — `src/lib.rs` held only `pub mod runtime;` and the run answered
`running 8 tests … 8 passed; 0 failed` (`sdk-runtime-first.log`) — and they are green with the glue
too (`sdk-test.log`). `cargo fmt --check` does not want to touch the file, which is what lets it
stay byte-identical.

### File map (0.1.0 → 0.2.0)

| 0.1.0 path | Now | Evidence |
|---|---|---|
| `mixins/mekanismtools/runtime.rs` | `src/runtime.rs`, copied with `cp` and `cmp`-checked | `retired-hnmod-0.1.0/mixins/mekanismtools/runtime.rs` |
| `mixins/mekanismtools/horizon-mixin.toml` (1 `[[module]]`, **0 `[[injection]]`**) | no plan; `pub mod runtime;` at the crate root | `retired-hnmod-0.1.0/mixins/` |
| `content/assets/` (223 files) | `assets/` | same bytes, 223/223 |
| `content/data/` (170 files) | `data/` | same bytes, 170/170 |
| `content/horizon-mod.toml` (content-only manifest, `api = "0.2"`) | the root `horizon-mod.toml` (identity + `[native]`) | `retired-hnmod-0.1.0/content/` |
| `content/mekanismtools.hmod` (168,015 B, 396 entries, sha256 `0cd30ee5…f4990` — the 2026-11-11 rebuild that added the two licence copies) | not a second package: content and code are one file now | `retired-hnmod-0.1.0/content/` |
| `compatibility.json` (horizon `1d63e0a5`, mixins `5a64af93`, `game.rs` hash) | `[native]` game/horizon/mixins in the manifest | `retired-hnmod-0.1.0/` |
| `rust-toolchain.toml` | gone: the pinned commit and the launcher decide the toolchain | `retired-hnmod-0.1.0/` |
| old `Cargo.toml` (`[lib] path = "mixins/…"`) + `Cargo.lock` | new `Cargo.toml` (one dependency, `horizon-mod-api` from `.horizon/sdk/`) | `retired-hnmod-0.1.0/` |
| `tools/horizon.py` (stage/check/test/build), `tools/stamp_license.py`, `tools/hmod-load.sh` | gone: the SDK ladder replaces the first two; the third's shared-game `--dev-mod` route does not exist for a native package (the control is `CONTROL_GAME` in `tools/e2e.sh`) | `retired-hnmod-0.1.0/tools/` |

**Kept and updated:** `tools/gen_content.py` (now writes `assets/` + `data/` at the package root,
generates no manifest, and clears only its own paths), `tools/unit.sh` (the SDK ladder),
`tools/e2e.sh` (launcher-built game + `CONTROL_GAME`), `tools/craft_check.py`, `tools/items.json`,
`FINDINGS.md`, `README.md`, `VALIDATION.md`, `notes.md`, `LICENSE`, `LICENSE-NOTICE.md`.
**Retired into evidence, not deleted:** the whole list in the table above.

### Carried content: byte-identical, all 393 files

A SHA-256 list of the retired `content/` (393 carried files, `content-baseline.sha256`) was taken
**before** the move; after it, the package's `assets/` + `data/` compare equal file for file:
`baseline=393 now=393 missing=0 extra=0 changed=0`. The carry tool proves the same thing
independently — `python3 tools/gen_content.py --check` regenerates the tree from the pack jar and
answers `content tree matches the jar census` / `Rust census: 72 item ids match the jar`
(`sdk-content-carry.log`), with the real 26.3 resources.

**No `data/mekanismtools/license/` copies any more.** 0.1.0 stamped `LICENSE` and
`LICENSE-NOTICE.md` into `data/` because a content-only `.hmod` had no other route; the SDK package
packs `LICENSE` and `LICENSE-NOTICE.md` at its root, so the review's [P1] ("include the MIT notice
in the distributed bundle") is satisfied by the file itself. Both entries are in the archive.

### The wire: one `[[module]]`, zero `[[injection]]`, nothing lost

| 0.1.0 | 0.2.0 | Mapped? |
|---|---|---|
| `[[module]] runtime` → `crates/horizon-client/src/game.rs`, injected as `crate::game::mekanismtools` | `pub mod runtime;` — an ordinary module of this crate | **yes**, same file, same tests |
| `[[injection]]` blocks | none existed, so none to map | **0 hooks, 0 gaps** |
| 72 item registrations | `data/mekanismtools/horizon/item/*.json` (content, unchanged) | **yes** |
| the creative tab, tags, recipes, models, textures, lang | `data/` + `assets/` (unchanged) | **yes** |

`src/lib.rs` therefore holds one `#[mod_api::horizon_mod] impl Hooks for Mod {}` with no methods.
That emptiness is the data-tier shape, not an omission: a mod's items come from its declarations,
and the crate exists so the census is compiled and tested and so the package is a native `.hmod`
the launcher can build. A later slice that needs behaviour (per-material stats, or the client half
that draws the shields' plates) adds methods or Parts there without moving any content.

### Manifest mapping

| 0.1.0 | 0.2.0 |
|---|---|
| `[mod] id = "mekanismtools"` | `id = "mekanismtools"` (also the resource namespace) |
| `[mod] version = "10.7.19"` | `version = "0.2.0"` — the port's version; a resubmission is always a new version |
| `[mod] priority = 100` | gone; ordering is `#[listener(priority = …)]` on a hook |
| `[compatibility] horizon_revision = "1d63e0a5…"` | `[native] horizon = "0b14f8acfd97fa2c750e42795249dcc981178ca4"` (40 hex) |
| mixins `5a64af938ec86b00d53d16a408aabc0038fb3e57` (bundle) | `[native] mixins = "e59da9094f0c2fdda6c627fe9eff22dec6a906f0"` — **it moved** |
| game 26.3 (template manifest) | `[native] game = "26.3"` |
| `[[module]] runtime` | no plan section (`pub mod runtime;`) |
| content manifest: `api = "0.2"`, `side = "both"`, `capabilities = ["registries"]` | the same three at the root, beside `[native]` |
| — | `license`, `homepage`, `issues` (kept in the **packed** manifest, checked with `unzip -p`) |

### Package (measured)

| Field | Value |
|---|---|
| file | `mekanismtools.hmod` (port root; built at `target/horizon-mod/mekanismtools.hmod`) |
| bytes | **176,051** |
| SHA-256 | `8819f044fc83cf273ed8439fc2f572bf4d838d500c3b956071692c698cbdf3f5` |
| entries | **401**: `horizon-mod.toml`, `Cargo.toml`, `LICENSE`, `LICENSE-NOTICE.md`, `README.md`, `uses.json`, `src/lib.rs`, `src/runtime.rs`, 223 under `assets/`, 170 under `data/` |
| `Cargo.lock` inside? | **no** (`rm -f Cargo.lock` right before the build; 0 entries) |
| reproducible? | **yes** — two clean builds (`rm -rf target/horizon-mod` between them) byte-identical, 176,051 B / `8819f044…` both (`sdk-build.log`, `sdk-build-second.log`, `sdk-reproducible.txt`) |
| registry check | `mekanismtools 0.2.0 (native-mod, format native-1/0b14f8ac…/e59da909…, for 26.3)`, 176,051 B, **EXIT 0** (`sdk-check.log`) — machine form `{"ok":true,…,"size":176051,"version":"0.2.0"}` (`sdk-check-json.log`) |
| fits the pinned build | `Mekanism: Tools:` / `0b14f8a  made for`, **EXIT 0** (`sdk-fits.log`) |

`uses.json` is the migration's own summary of the code half: **6 entries** —
`macro:horizon_mod`, `trait:Hooks`, `capability:registries`, and the API vocabulary the macro's
generated dispatch references (`capability:horizon:items`, `trait:ResourceHandler`,
`type:ItemResource`). **No hook and no method of this port's is in it**, which is exactly what a
zero-injection census should report (`sdk-uses-from-package.json`).

### The ladder (all inside slot leases, `CARGO_INCREMENTAL=0`, no `--target-dir`)

The runner runs a forwarded job **in the port directory**, so every step below used `--port .`
from inside the port and no `cd` (trap 4).

| Step | Command | Result |
|---|---|---|
| runtime tests, before the glue | `cargo test --offline` (`src/lib.rs` = `pub mod runtime;`) | **8 passed**, 0 failed (`sdk-runtime-first.log`) |
| tests, with the glue | `cargo test --offline` | **8 passed**, 0 failed (`sdk-test.log`) |
| the census can fail | the same crate with one `ITEMS` id renamed, in `target/mutant/` | **2 failed** — `steel_sword is missing`, `ITEMS must be the table-derived census` (`sdk-mutant-test.log`) |
| the carry can fail | one item declaration's template changed, `gen_content.py --check` | `differs data/mekanismtools/horizon/item/steel_sword.json`, exit 1 (`sdk-mutant-carry.log`) |
| lints | `cargo clippy --all-targets --offline -- -D warnings` | exit 0, **0 warning/error lines** (`sdk-clippy.log`) |
| formatting | `cargo fmt --check` (**not** `--all`) | exit 0 (`sdk-fmt.log`) |
| carry | `python3 tools/gen_content.py --check` | `content tree matches the jar census` (`sdk-content-carry.log`) |
| package | `rm -f Cargo.lock && cargo horizon-mod build` | `SDK 0b14f8a … in ./.horizon/sdk`, `Built ./target/horizon-mod/mekanismtools.hmod` (`sdk-build.log`) |
| check / fits | `cargo horizon-mod check` / `fits … --build nightly` | both EXIT 0 (quoted above) |
| entries | `unzip -l mekanismtools.hmod` | 401 files (`sdk-entries.txt`) |
| in-game | `tools/e2e.sh` | **not run**: `horizon-launcher` is not installed, so no game carries this package (gap 9; `sdk-e2e-not-run.log` shows the script's refusal, `exit=64`) |

### Traps this port adds to the recipe

1. **A data-tier `runtime.rs` can be `#[cfg(test)]` all the way down.** This one is one
   `mod tests` block from line 24 to the end, so in a non-test build `pub mod runtime;` is an empty
   module: no `dead_code`, no `uses.json` entry, and the tests still run. Do not "fix" the
   emptiness — the census is a test, not the mod's behaviour.
2. **The old content generator wiped its whole output root.** With `content/` replaced by the
   package root, its `for child in out.iterdir(): rmtree` would have deleted `src/`, the manifest,
   `LICENSE` and the delivered `.hmod`. `tools/gen_content.py` now clears exactly the six paths it
   owns (`GENERATED`) and writes `assets/` + `data/` beside the sources.
3. **A root `.toml` that is not the manifest refuses the build.** `rust-toolchain.toml` had to move
   to evidence even though it is not a `.rs` file: the packer's own rule
   (`horizon-mod-package/src/manifest.rs`: a name ending `.rs`, or `.toml` other than
   `horizon-mod.toml`, outside `src/`, `assets/`, `data/` and the root documents) answers
   `unexpected package path: <name>`. Read from the tool's source before the first build rather
   than measured — which is why it is the one trap here with no failing log.
4. **`build-slot.sh run` executes in the port directory when the job is forwarded.** Running
   `bash -c 'cd ports/mekanismtools && cargo test'` from the campaign root answered
   `cd: ports/mekanismtools: No such file or directory`; the SDK ladder runs `--port .` from inside
   the port, with no `cd`.
5. **`license`/`homepage`/`issues` are legal manifest fields at this tool build.** The recipe's
   trap 7 says they are stripped; the packed manifest keeps all three, so the check that matters is
   `unzip -p mekanismtools.hmod horizon-mod.toml`, and the trap text is now known to be stale.
6. **`check --json` reports `"capabilities":[]` and `"side":null` for a native package** with
   `capabilities = ["registries"]` and `side = "both"` in the manifest. That is the checker's
   report shape (`mekanismgenerators` records the same for `side` in its trap 9), not a manifest
   error.
7. **Rewrite `README.md` before the final build.** It is a root document, so the packer includes it
   and its bytes are in the hash: the first build of this port was 175,575 B, and the same sources
   with the rewritten README are 176,051 B. Everything not packed (`notes.md`, `FINDINGS.md`,
   `tools/`, `target/`) can change afterwards without touching the artifact.
8. **The delivered `.hmod` can sit at the package root.** The packer skips it (not a source file,
   not a `.toml`), so `cp target/horizon-mod/mekanismtools.hmod .` does not poison the next build —
   unlike the retired format, where `content/` held the deliverable as a second package.
9. **A native package has no `--dev-mod` control leg.** `tools/hmod-load.sh` loaded the old content
   `.hmod` on a shared unmodded game; a native package is compiled into the client, so the negative
   control is a second launcher-built binary (`CONTROL_GAME=`) where the ids must be unknown.
10. **A mutant compile belongs under the port's `target/`, not `/tmp`.** The 7.5 GB tmpfs filled at
    `rustc-LLVM ERROR: IO failure on output stream: No space left on device`; the fail-capability
    runs above used `target/mutant/` (disposed with `target/` at the end of the job).

### Gaps after the migration

The behaviour gaps 1–8 above are unchanged (per-material stats, the 55 parent-dependent recipes,
paxel crafting, shields, trims, advancements/translations, piglin neutrality and knockback
resistance, the parent's own content). The migration adds record-level ones:

9. **No in-game run at 0.2.0.** `horizon-launcher` is not installed here, and an SDK package is
    compiled **into** the client by it, so no game carries this package. `tools/e2e.sh` was
    rewritten for that launch (`GAME=`, optional `CONTROL_GAME=`, `SELFTEST=1` kept, no
    `--dev-mod`) and was **not run**; the 0.1.0 runs remain the behaviour's evidence —
    `e2e-default.log` (PASS + `EXIT:0`), `e2e-selftest.log` (FAIL + `EXIT:1`), `hmod-load.log` — and
    they are the same scenario, the same 393 carried files and a byte-identical `runtime.rs`.
    **The first thing a 0.2.0 run must confirm** is the one claim no offline check covers: that the
    72 declarations make the items exist with the package compiled in (the scenario's first phase,
    `72/72` gives), and that `CONTROL_GAME` refuses them.
10. **`upstream_ready.py` still reads the retired layout** and reports
    `content-only port with no .hmod delivered`, `no .hmod/.hnmod delivered in the port`,
    `no compatibility.json`. The deliverable exists and `check` accepts it; the tool needs the SDK
    layout (orchestrator tooling, not this job's file).
11. **The e2e's control client defaults to the `1d63e0a5` shared `horizon-ctl`.** A 0.2.0 run must
    pass `CTL=` built from the same SDK build as `GAME` if the protocol differs; the script says so
    at the top.

## Upstream defects fixed

None found in this migration. Nothing about the carried data, the declarations, the tags or the
recipes changed: 393 files, byte for byte. The 0.1.0 carry is where the port chose its deviations
(`## Slice boundary`, `## Template map` above) and where reviewer items were repaired; the
migration only moved them into the new package.

### Changelog (0.2.0) — first publication

> **0.2.0 — first publication, as an SDK `.hmod`.** Horizon's mod-API merge (launcher ≥ 0.2.70)
> retired the `.hnmod` container; this is Mekanism: Tools rebuilt in the one-file format, so
> version 0.2.0 is the first published release (an earlier 0.1.0 bundle was reviewed in #673 and
> never merged — nothing is superseded). What changed for `api = "0.2"`: one flat
> `mekanismtools.hmod` now carries the code *and* the content — `horizon-mod.toml` with
> `api = "0.2"`, `side = "both"`, `capabilities = ["registries"]` and exact `[native]` pins
> (Horizon `0b14f8ac`, mixins `e59da909`, 26.3), the 72 item declarations and the mod's own
> models, textures, equipment layers, lang, 65 recipes and tags at the package root, and
> `src/lib.rs` with the one `impl mod_api::Hooks` — empty, because a data-tier port has no
> behaviour hook. `src/runtime.rs`, the 72-item census and its 8 tests, is byte-identical to the
> retired module and its tests were green before the glue existed. The mixin plan, the
> compatibility file, the embedded second package, `rust-toolchain.toml` and the staging tools are
> gone; `tools/gen_content.py` regenerates the carried tree at the new root and proves it unchanged.
> Package: 401 entries, **176,051 B**, sha256
> `8819f044fc83cf273ed8439fc2f572bf4d838d500c3b956071692c698cbdf3f5`, `check` and `fits` exit 0,
> two clean builds byte-identical. Same 72 items and the same limitations as before: an add-on that
> needs Mekanism for 55 of its recipes, paxels creative/give only, template stats, vanilla shields.
> No 0.2.0 in-game run: the launcher is not installed in this environment.

Skills: superpowers/using-superpowers,brainstorming,writing-plans,test-driven-development,systematic-debugging,verification-before-completion; BeautifulRust/rust-best-practices,rust-port,rust-review
