# Mekanism: Tools — Horizon port

A port of [Mekanism: Tools](https://github.com/mekanism/Mekanism) by Aidan C. Brady and the Mekanism contributors for
Horizon. A data-tier carry: the 72-item census is a test-only Rust module (no injection).

**Status:** the slice below is what works today; the second list is what is
missing. Nothing here claims parity with the original.

## What works

- 72 items: 30 tools (axe, hoe, pickaxe, shovel and sword in bronze, lapis lazuli,
  osmium, refined glowstone, refined obsidian and steel), 12 paxels, 24 armour pieces
  and 6 shields.
- The mod's own item models, 78 textures, equipment definitions, 65 recipes, the `c:`
  and `minecraft:` tool/armour tags and the language file.
- All 72 items are give-able, all 24 armour pieces equip into their own slot, and the
  creative tab lists every item.
- Paxels carry the pickaxe/axe/shovel rules of the three tools they replace.

## Not yet ported

- **Known defect, being fixed in another job:** the steel sword currently deals the same
  damage as a stick in the in-game check, so attack damage is not yet read from the
  item; the end-to-end run fails on that assertion. Do not publish this entry until that
  run passes.
- An item's harvest tier, durability and attack damage are the vanilla template's
  (iron/diamond/golden/netherite), not Mekanism's per-material numbers.
- There is no `notes.md` in the port yet, so the deviations above are recorded only here
  and in the evidence logs.
- Shields use the vanilla shield template; upstream's own shield behaviour is not
  carried.

## Install

1. Take `mekanismtools.hmod` from this repository (or build it below).
2. Put it in the game folder's `horizon-mods` folder — the game folder is the
   one holding `options.txt`.
3. Mods are off by default: enable this one in the game's mod list.

To try it without installing, start the game with
`--dev-mod mekanismtools.hmod`.

## Build from source

This is a content-only mod: `content/horizon-mod.toml` plus `assets/` and
`data/`.

```sh
cd content && cargo horizon-mod build    # packs content/ into the .hmod and checks it
python3 tools/gen_content.py          # regenerates content/ from the pack jar
```

`cargo-horizon-mod` comes from the Horizon repository
(`cargo install --git https://github.com/horizon-rust/horizon cargo-horizon-mod`).
`tools/` holds the content generator and the in-game harness. The harness
expects a campaign checkout (`$CAMPAIGN_ROOT`) with the prepared 26.3 resources
(`$HORIZON_RES`, default `~/Desktop/horizon/.local/horizon-client/26.3`).

## Compatibility

- Horizon `1d63e0a` (see `compatibility.json` for the exact revision this
  artifact was built against).
- horizon-mixins `5a64af93`, schema 6.
- Minecraft: Java Edition 26.3.

## Credits

Mekanism: Tools 10.7.19 by Aidan C. Brady and the Mekanism contributors — <https://github.com/mekanism/Mekanism>.
The original copyright and licence notices are kept in
[LICENSE](LICENSE); [LICENSE-NOTICE.md](LICENSE-NOTICE.md) records where each
was read from.

This is an unofficial port: Horizon is not affiliated with the original author.

## Licence

MIT — see [LICENSE](LICENSE).

## Contributing

The "Not yet ported" list is the gap list; an issue or a pull request that
closes one item is welcome. Please keep the original notices and say which
slice you are working on.
