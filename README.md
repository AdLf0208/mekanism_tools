# Mekanism: Tools — Horizon port (slice 1)

Mekanism: Tools 10.7.19.85 (MIT, `mekanism/Mekanism`) carried into one flat
Horizon SDK package (`api = "0.2"`) for **Minecraft Java 26.3** on Horizon
`0b14f8ac` / horizon-mixins `e59da909`.

**Class `content`, tier `data`** — a carry-over: 72 items (6 Mekanism materials
× 7 tools + 4 armour slots, plus the six vanilla paxels) declared from 26.3
vanilla item templates, with the jar's own models, textures, language file,
recipes and tags. No block entities, no renderers, no hooks.

- `horizon-mod.toml` — the manifest and the only identity (`id`, `version`,
  `api = "0.2"`, `side`, `capabilities`, the exact `[native]` pins).
- `assets/`, `data/` — the carried content (393 files), byte-identical to the
  retired `content/` tree: item declarations, models, textures, equipment
  layers, lang, recipes, tags, creative tab.
- `src/lib.rs` — the one `impl Hooks`, empty on purpose: a data-tier port has no
  behaviour hook, and this is what makes the package native.
- `src/runtime.rs` — the pure item census (families, template map, harvest
  tiers, equipment ids, paxel rule shape), byte-identical to the retired
  `mixins/mekanismtools/runtime.rs`, with its 8 tests.
- `tools/gen_content.py` — regenerates `assets/` and `data/` from the pack jar
  and checks the Rust census against it (`--check`).
- `tools/unit.sh` — the offline ladder (fmt, tests, clippy, content check).
- `tools/e2e.sh`, `tools/craft_check.py` — the in-game scenario (needs a
  launcher-built game; see `notes.md`).
- `FINDINGS.md` — what the jar says about the families, the tiers, the recipes
  and what the port deliberately leaves out.
- `notes.md` — scope, template map and deviations, gaps, verification table and
  the `## Migration to the SDK format` record.

`mekanismtools.hmod` in this directory is the delivered package.
The retired `.hnmod` tree (mixin plan, `compatibility.json`, the old `content/`
manifest and package, the old Cargo manifest and tooling) is kept as evidence at
`../_shared/evidence/mekanismtools/retired-hnmod-0.1.0/`.

**Local-only** until the maintainer approves publishing (see `LICENSE`).

```sh
python3 tools/gen_content.py --check        # assets/ + data/ == jar census
ports/tools/build-slot.sh run --job mtk --port . --step test  -- cargo test --offline
ports/tools/build-slot.sh run --job mtk --port . --step lint  -- cargo clippy --all-targets -- -D warnings
rm -f Cargo.lock
ports/tools/build-slot.sh run --job mtk --port . --step build -- cargo horizon-mod build
cargo horizon-mod check mekanismtools.hmod
cargo horizon-mod fits mekanismtools.hmod --build nightly
```
