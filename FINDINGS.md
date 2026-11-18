# FINDINGS — Mekanism: Tools 10.7.19.85 (slice 1)

Read from the pack jar itself (`MekanismTools-1.21.1-10.7.19.85.jar`, SHA-1
`4433b3ee…50bc`) — its data half, its lang and its loader metadata. No Java was
read, and no class file was opened: the jar's `mekanism/tools/**/*.class` files
were only counted, never parsed.

## 1. The item families (from `assets/mekanismtools/models/item/`)

| Family | Members | Count |
|---|---|---|
| Modded tools | `{bronze, lapis_lazuli, osmium, refined_glowstone, refined_obsidian, steel} × {axe, hoe, paxel, pickaxe, shield, shovel, sword}` | 42 |
| Modded armour | the same six materials × `{helmet, chestplate, leggings, boots}` | 24 |
| Vanilla paxels | `{wood, stone, iron, gold, diamond, netherite}_paxel` | 6 |
| | | **72** |

The jar also ships 240 `*_trim` armour overlay models and 6 `*_shield_blocking`
display models; neither is an item (see §6).

## 2. The harvest tiers are data (the jar's own block tags)

`data/mekanismtools/tags/block/incorrect_for_<material>_tool.json` holds one
entry each:

| Material | Tag body | Tier |
|---|---|---|
| `lapis_lazuli` | `#minecraft:incorrect_for_stone_tool` | stone |
| `bronze` | `#minecraft:incorrect_for_iron_tool` | iron |
| `osmium` | `#minecraft:incorrect_for_iron_tool` | iron |
| `refined_glowstone` | `#minecraft:incorrect_for_diamond_tool` | diamond |
| `steel` | `#minecraft:incorrect_for_diamond_tool` | diamond |
| `refined_obsidian` | `#minecraft:incorrect_for_netherite_tool` | netherite |

That is the authoritative mapping the port uses to pick each material's vanilla
template (an item's harvest gate is exactly what `minecraft:tool.rules[0]` is).

## 3. Armour classes (public documentation, since the jar has no data for it)

The project's wiki ("Armor", `https://wiki.aidancbrady.com/wiki/Armor`) lists a
defence total and a toughness per set; the per-piece durability pages give the
durability per slot:

| Set | Defence | Toughness | Durability (helmet/chest/legs/boots) |
|---|---:|---:|---|
| Lapis Lazuli | 9 | 0 | 143 / 208 / 195 / 169 |
| Bronze | 18 | 4 | 385 / 560 / 525 / 455 |
| Osmium | 21 | 12 | 330 / 480 / 450 / 390 |
| Refined Glowstone | 20 | 0 | 198 / 288 / 270 / 234 |
| Steel | 20 | 8 | 440 / 640 / 600 / 520 |
| Refined Obsidian | 30 | 20 | 550 / 800 / 750 / 650 |

Vanilla for comparison (26.3 `items.json`): leather 7/0, gold 11/0, chainmail
12/0, iron 15/0, diamond 20/8, netherite 20/12.

The port takes the **nearest vanilla class** and records the difference rather
than inventing per-piece attribute distributions (see `notes.md`).

## 4. Recipes (`data/mekanismtools/recipe/`)

| Type | Files | Port decision |
|---|---:|---|
| `minecraft:crafting_shaped` | 60 | carried (10 per modded material: 4 armour, 5 tools, 1 shield; the paxel has no shaped recipe) |
| `minecraft:smelting` / `minecraft:blasting` | 7 + 7 | the 4 that yield **vanilla** nuggets (gold, iron) carried; the 10 that yield `mekanism:nugget_*` dropped — the parent port registers no nuggets |
| `mekanismtools:paxel` | 11 | **skipped**: a custom recipe type no vanilla reader knows (6 modded + 5 vanilla paxels; `netherite_paxel` is a smithing transform instead) |
| `mekanismtools:banner_shield` | 1 | **skipped**: custom type |
| `minecraft:smithing_transform` | 1 | carried (`diamond_paxel` + netherite ingot + upgrade template → `netherite_paxel`) |
| | **87** | **65 carried, 22 skipped** |

Ingredient tags: the modded tools/armour name `c:ingots/<material>`,
`c:gems/lapis` and `c:rods/wooden`. Only the last two have a member in the pack
(`minecraft:lapis_lazuli`, `minecraft:stick`), so the port writes those two
convention tags by hand and the other 55 shaped recipes load with an **empty
ingredient** — they parse, they never match, and they start working the day the
parent port registers its ingots (recorded as a gap, per
`AGENTS.md`/`carry-pipeline.md` §4.6).

## 5. Tags and lang

- `data/minecraft/tags/item/*.json` (21): `axes`, `pickaxes`, `shovels`, `hoes`,
  `swords`, `head/chest/leg/foot_armor`, `freeze_immune_wearables`,
  `piglin_loved`, `cluster_max_harvestables`, `breaks_decorated_pots`,
  `enchantable/{durability,mining,mining_loot,sharp_weapon,weapon}`. Carried
  unchanged: they are what makes vanilla enchantments, tool behaviour and mob
  reactions see the items.
- `data/c/tags/item/tools{,.json}`: `tools`, `tools/melee_weapon`,
  `tools/mining_tool`, `tools/paxel`, `tools/shield` — carried unchanged.
- `assets/mekanismtools/lang/en_us.json`: 800 keys; the 72 `item.mekanismtools.*`
  names are all there, and the port carries the file whole (the item display
  name comes from `item.<ns>.<path>`, `creative.rs:126`).
- No creative-tab JSON exists (upstream builds its tab in code), so the port
  writes `data/mekanismtools/horizon/creative_tab/all.json` with the 72 items.

## 6. What the jar carries that the port does not

| Asset | Why |
|---|---|
| 240 `*_trim` armour models | their `layer1` names `minecraft:trims/items/<piece>_trim_<palette>`; 26.3 ships a single `*_trim.png` per piece and 26.3 vanilla uses `_iron_darker`-style names, so a carried overlay would draw a missing texture. A later slice can build the `minecraft:select` definition once the palette scheme is confirmed |
| 6 `*_shield_blocking` models + `entity/shield/<material>.png` | the blocking model is selected by a **custom item-model property** (`mekanismtools:blocking`, `RenderMekanismShieldItem` in the client half) which the content format cannot express |
| `assets/minecraft/atlases/shield_patterns.json` | a `minecraft`-namespace file: a content mod may only own its own namespace |
| 6 advancements | 1.21.1 trigger/predicate shapes; not needed by the slice and not worth a lockstep carry |
| 80 non-English lang files | `en_us` is the slice's contract; translations are additive later |
| `logo.png`, `pack.mcmeta` | jar packaging, not content |

## 7. Differences from the rewrite (recorded, not hidden)

1. **Stats follow the template.** Upstream sets per-material durability, mining
   speed, attack damage, armour points and enchantability in its material
   classes; this pin reads tool stats from the **item** (fine here) but the
   numbers live in Java, so the port takes the vanilla class of the same tier
   instead of guessing them (§2/§3 and `notes.md` "Template map and deviations").
2. **A paxel's three tools are expressed as one `minecraft:tool` rule union**
   (pickaxe + axe + shovel `mineable` tags at the template's speed) plus
   `minecraft:block_transformer: minecraft:axe`, because a paxel is
   pickaxe + axe + shovel upstream. Its attack damage is the template
   pickaxe's, not upstream's.
3. **The shields render as vanilla shields.** Their plate texture and blocking
   model need the client half (§6).
4. **Armour renders with the mod's own layers** through 26.3 equipment assets
   (`assets/mekanismtools/equipment/<material>.json` +
   `textures/entity/equipment/{humanoid,humanoid_leggings}/<material>.png`),
   mapped from upstream's `textures/models/armor/<material>_layer_{1,2}.png`.
