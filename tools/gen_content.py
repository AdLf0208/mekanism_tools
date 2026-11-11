#!/usr/bin/env python3
"""Generate the Mekanism: Tools content tree from the pack's own jar.

Source of truth: the ATM10 jar `MekanismTools-1.21.1-10.7.19.85.jar`
(SHA-1 4433b3eec0a5a0bf415d873e710a1cecea5850bc, MIT). This is a clean-room
carry: assets and data come from the jar's own files, the item declarations and
the behaviour come from 26.3 vanilla item templates, and no Java was read.

Item families (from the jar's `assets/mekanismtools/models/item/*.json` and
`data/mekanismtools/recipe/**`):

  6 Mekanism materials x 7 tool kinds  = 42
  6 materials x 4 armour slots         = 24
  6 vanilla paxels (wood..netherite)   =  6
                                        = 72 items

Template choice is evidence-based, never invented:

  * a tool's tier is the jar's own block tag
    `data/mekanismtools/tags/block/incorrect_for_<material>_tool.json`
    (lapis -> stone, bronze/osmium -> iron, glowstone/steel -> diamond,
    obsidian -> netherite);
  * an armour piece uses the material class with the nearest documented defence
    total (the project's public wiki, "Armor": lapis 9, bronze 18, osmium 21,
    glowstone 20, steel 20, obsidian 30; vanilla leather 7, gold 11, chain 12,
    iron 15, diamond 20, netherite 20) - the deviations are in notes.md;
  * the paxel combines the template's pickaxe rules with the axe and shovel
    `mineable` tags at the template's own speed (read from the 26.3 item table),
    because a paxel is pickaxe + axe + shovel upstream.

Usage:
    python3 tools/gen_content.py [--jar PATH] [--out DIR] [--check]

`--check` regenerates into a temporary directory and compares every file with
the committed content tree, and checks the Rust census (`ITEMS`) against the
jar's item set. Exit 1 on any difference.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT.parents[1]
DEFAULT_JAR = CAMPAIGN / "ports/_shared/licence-cache/MekanismTools-1.21.1-10.7.19.85.jar"
DEFAULT_OUT = ROOT / "content"
DEFAULT_RES = Path.home() / "Desktop/horizon/.local/horizon-client/26.3"
JAR_SHA1 = "4433b3eec0a5a0bf415d873e710a1cecea5850bc"

# (material, tool tier for templates, armour template material)
MATERIALS = [
    ("bronze", "iron", "diamond"),
    ("lapis_lazuli", "stone", "golden"),
    ("osmium", "iron", "diamond"),
    ("refined_glowstone", "diamond", "diamond"),
    ("refined_obsidian", "netherite", "netherite"),
    ("steel", "diamond", "diamond"),
]
# Tool kinds: name -> vanilla suffix (paxel and shield are special-cased).
TOOL_KINDS = ["axe", "hoe", "paxel", "pickaxe", "shield", "shovel", "sword"]
ARMOUR_SLOTS = [("helmet", "head"), ("chestplate", "chest"),
                ("leggings", "legs"), ("boots", "feet")]
# Vanilla paxels: item prefix -> template material.
VANILLA_PAXELS = [("wood", "wooden"), ("stone", "stone"), ("iron", "iron"),
                  ("gold", "golden"), ("diamond", "diamond"),
                  ("netherite", "netherite")]

# The jar's `data/mekanismtools/tags/block/incorrect_for_<material>_tool.json`
# values, as carried (the tag file itself is the evidence).
INCORRECT_FOR = {
    "bronze": "minecraft:incorrect_for_iron_tool",
    "lapis_lazuli": "minecraft:incorrect_for_stone_tool",
    "osmium": "minecraft:incorrect_for_iron_tool",
    "refined_glowstone": "minecraft:incorrect_for_diamond_tool",
    "refined_obsidian": "minecraft:incorrect_for_netherite_tool",
    "steel": "minecraft:incorrect_for_diamond_tool",
}

# Convention tags the 1.21.1 recipes need, with a member this port has
# (`carry-pipeline.md` pitfall 6: a `c:` tag never ships in the vanilla jars).
CONVENTION_TAGS = {
    "data/c/tags/item/rods/wooden.json": ["minecraft:stick"],
    "data/c/tags/item/gems/lapis.json": ["minecraft:lapis_lazuli"],
}

# Recipes whose custom types no vanilla reader knows, or whose result item the
# parent Mekanism port does not register. Recorded in notes.md, not carried.
SKIP_RECIPE_TYPES = {"mekanismtools:paxel", "mekanismtools:banner_shield"}


def build_plan(res: Path):
    """Every item: id, family, template, component patch, extra flags."""
    items = []

    tools = json.loads((res / "items.json").read_text())

    def tool_rules(template: str, incorrect: str) -> dict:
        rules = tools[template]["minecraft:tool"]["rules"]
        pick = next(r for r in rules if r.get("correct_for_drops"))
        speed = pick["speed"]
        return {
            "rules": [
                {"blocks": incorrect, "correct_for_drops": False},
                {"blocks": "#minecraft:mineable/pickaxe",
                 "correct_for_drops": True, "speed": speed},
                {"blocks": "#minecraft:mineable/axe",
                 "correct_for_drops": True, "speed": speed},
                {"blocks": "#minecraft:mineable/shovel",
                 "correct_for_drops": True, "speed": speed},
            ]
        }

    for material, tier, armour in MATERIALS:
        for kind in TOOL_KINDS:
            if kind == "shield":
                template = "minecraft:shield"
                components = {}
                family = "shield"
            elif kind == "paxel":
                template = f"minecraft:{tier}_pickaxe"
                components = {
                    "minecraft:tool": tool_rules(
                        template, f"#mekanismtools:incorrect_for_{material}_tool"),
                    "minecraft:block_transformer": "minecraft:axe",
                }
                family = "paxel"
            else:
                template = f"minecraft:{tier}_{kind}"
                components = {}
                family = "tool"
            items.append({
                "id": f"{material}_{kind}",
                "family": family,
                "material": material,
                "kind": kind,
                "template": template,
                "components": components,
                "armour_slot": None,
            })
        for slot, part in ARMOUR_SLOTS:
            template = f"minecraft:{armour}_{slot}"
            equippable = {
                "slot": part,
                "asset_id": f"mekanismtools:{material}",
                "equip_sound": tools[template]["minecraft:equippable"]
                .get("equip_sound", "minecraft:item.armor.equip_generic"),
            }
            items.append({
                "id": f"{material}_{slot}",
                "family": "armour",
                "material": material,
                "kind": slot,
                "template": template,
                "components": {"minecraft:equippable": equippable},
                "armour_slot": part,
            })

    for prefix, tier in VANILLA_PAXELS:
        template = f"minecraft:{tier}_pickaxe"
        items.append({
            "id": f"{prefix}_paxel",
            "family": "paxel",
            "material": prefix,
            "kind": "paxel",
            "template": template,
            "components": {
                "minecraft:tool": tool_rules(
                    template, f"#minecraft:incorrect_for_{tier}_tool"),
                "minecraft:block_transformer": "minecraft:axe",
            },
            "armour_slot": None,
        })
    return items


def rewrite_ingredient(value):
    """1.21.1 `{"item": X}` / `{"tag": T}` -> 26.3 `X` / `#T`."""
    if isinstance(value, str):
        return value
    if isinstance(value, dict) and "item" in value:
        return value["item"]
    if isinstance(value, dict) and "tag" in value:
        return "#" + value["tag"]
    raise SystemExit(f"unexpected ingredient: {value!r}")


def rewrite_recipe(name: str, recipe: dict) -> dict | None:
    kind = recipe.get("type", "")
    if kind in SKIP_RECIPE_TYPES:
        return None
    if kind == "minecraft:crafting_shaped":
        recipe["key"] = {k: rewrite_ingredient(v) for k, v in recipe["key"].items()}
        return recipe
    if kind == "minecraft:smithing_transform":
        for field in ("addition", "base", "template"):
            recipe[field] = rewrite_ingredient(recipe[field])
        return recipe
    if kind in ("minecraft:smelting", "minecraft:blasting"):
        result = recipe.get("result", {})
        if str(result.get("id", "")).startswith("mekanism:"):
            return None  # the parent port registers no nuggets
        recipe["ingredient"] = rewrite_ingredient(recipe["ingredient"])
        return recipe
    raise SystemExit(f"{name}: unhandled recipe type {kind}")


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def generate(jar: Path, out: Path, res: Path) -> dict:
    """Write the whole content tree; return a census dict."""
    import hashlib
    sha1 = hashlib.sha1(jar.read_bytes()).hexdigest()
    if sha1 != JAR_SHA1:
        raise SystemExit(f"{jar}: SHA-1 {sha1} is not the pack's {JAR_SHA1}")

    items = build_plan(res)
    ids = [i["id"] for i in items]
    if len(set(ids)) != len(ids):
        raise SystemExit("duplicate item ids in the plan")
    if len(ids) != 72:
        raise SystemExit(f"plan has {len(ids)} items, expected 72")

    if out.exists():
        shutil.rmtree(out)
    (out / "data").mkdir(parents=True)

    vanilla_shield = res / "assets/minecraft/items/shield.json"
    shield_definition = json.loads(vanilla_shield.read_text())

    archive = zipfile.ZipFile(jar)
    names = set(archive.namelist())
    skipped = []

    # ---------------------------------------------------------------- manifest
    (out / "horizon-mod.toml").write_text(
        "# Mekanism: Tools for Horizon - a content-only port of the pack's\n"
        "# MekanismTools-1.21.1-10.7.19.85.jar (MIT, mekanism/Mekanism).\n"
        "# The items are declared from 26.3 vanilla templates, the assets, lang,\n"
        "# recipes and tags are the jar's own files (26.3 formats). It is\n"
        "# LOCAL-ONLY until the maintainer approves publishing (ARCHITECTURE.md 8).\n"
        'id = "mekanismtools"\n'
        'name = "Mekanism: Tools"\n'
        'version = "10.7.19"\n'
        'api = "0.2"\n'
        'side = "both"\n'
        'capabilities = ["registries"]\n')

    # ------------------------------------------------------------ item decls
    for item in items:
        name = item["id"]
        components = {"minecraft:item_model": f"mekanismtools:{name}"}
        components.update(item["components"])
        write_json(out / f"data/mekanismtools/horizon/item/{name}.json",
                   {"template": item["template"], "components": components})

    # ---------------------------------------------------------- creative tab
    write_json(out / "data/mekanismtools/horizon/creative_tab/all.json", {
        "title": "Mekanism: Tools",
        "icon": "mekanismtools:steel_pickaxe",
        "items": [f"mekanismtools:{name}" for name in ids],
    })

    # ------------------------------------------------------------------ tags
    for entry in sorted(x for x in names if x.startswith(
            ("data/mekanismtools/tags/", "data/minecraft/tags/", "data/c/tags/"))
            and x.endswith(".json")):
        target = out / entry
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(archive.read(entry))
    for rel, values in CONVENTION_TAGS.items():
        write_json(out / rel, {"values": values})

    # -------------------------------------------------------------- recipes
    carried_recipes = 0
    for entry in sorted(x for x in names
                        if x.startswith("data/mekanismtools/recipe/") and x.endswith(".json")):
        recipe = json.loads(archive.read(entry))
        rewritten = rewrite_recipe(entry, recipe)
        if rewritten is None:
            skipped.append(entry)
            continue
        write_json(out / entry, rewritten)
        carried_recipes += 1

    # --------------------------------------------------------------- models
    armour = {i["id"] for i in items if i["family"] == "armour"}
    shields = {i["id"] for i in items if i["family"] == "shield"}
    models = 0
    for item in items:
        name = item["id"]
        if name in shields:
            # The vanilla shield's special model draws the 3D plate; the mod's
            # own plate texture needs the client renderer (recorded gap).
            write_json(out / f"assets/mekanismtools/items/{name}.json",
                       shield_definition)
            continue
        entry = f"assets/mekanismtools/models/item/{name}.json"
        model = json.loads(archive.read(entry))
        for key in ("overrides",):  # 1.21.1 trim/item properties: 26.3 selects
            model.pop(key, None)
        write_json(out / f"assets/mekanismtools/models/item/{name}.json", model)
        write_json(out / f"assets/mekanismtools/items/{name}.json",
                   {"model": {"type": "minecraft:model",
                              "model": f"mekanismtools:item/{name}"}})
        models += 1

    # ------------------------------------------------------------- textures
    textures = 0
    for entry in sorted(x for x in names
                        if x.startswith("assets/mekanismtools/textures/item/")
                        and x.endswith(".png")):
        target = out / entry
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(archive.read(entry))
        textures += 1

    # ------------------------------------------- armour equipment (worn look)
    equipment = 0
    for material, _tier, _armour in MATERIALS:
        layers = {}
        for kind, source in (
                ("humanoid", f"textures/models/armor/{material}_layer_1.png"),
                ("humanoid_leggings", f"textures/models/armor/{material}_layer_2.png")):
            entry = f"assets/mekanismtools/{source}"
            if entry not in names:
                raise SystemExit(f"missing armour layer {entry}")
            target = (out / f"assets/mekanismtools/textures/entity/equipment/"
                             f"{kind}/{material}.png")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.read(entry))
            layers[kind] = [{"texture": f"mekanismtools:{material}"}]
        write_json(out / f"assets/mekanismtools/equipment/{material}.json",
                   {"layers": layers})
        equipment += 1

    # ------------------------------------------------------------------ lang
    (out / "assets/mekanismtools/lang").mkdir(parents=True, exist_ok=True)
    (out / "assets/mekanismtools/lang/en_us.json").write_bytes(
        archive.read("assets/mekanismtools/lang/en_us.json"))

    census = {
        "jar": jar.name,
        "jar_sha1": sha1,
        "counts": {
            "items": len(ids),
            "tool_items": sum(1 for i in items if i["family"] == "tool"),
            "paxels": sum(1 for i in items if i["family"] == "paxel"),
            "shields": len(shields),
            "armour": len(armour),
            "models": models,
            "textures": textures,
            "equipment": equipment,
            "recipes": carried_recipes,
            "skipped_recipes": len(skipped),
            "trim_models_skipped": sum(
                1 for x in names
                if x.startswith("assets/mekanismtools/models/item/")
                and x.endswith("_trim.json")),
        },
        "skipped_recipes": skipped,
        "items": [
            {k: v for k, v in item.items() if k != "components"} | {
                "item_model": f"mekanismtools:{item['id']}"}
            for item in items
        ],
    }
    return census


def rust_census(path: Path) -> list[str]:
    text = path.read_text()
    match = re.search(r"pub const ITEMS: \[&str; \d+\] = \[(.*?)\];", text, re.S)
    if not match:
        raise SystemExit(f"{path}: no `ITEMS` array")
    return re.findall(r'"([^"]+)"', match.group(1))


def compare(a: Path, b: Path) -> int:
    problems = []
    files_a = {p.relative_to(a) for p in a.rglob("*") if p.is_file()}
    files_b = {p.relative_to(b) for p in b.rglob("*") if p.is_file()}
    for missing in sorted(files_b - files_a):
        problems.append(f"missing {missing}")
    for extra in sorted(files_a - files_b):
        problems.append(f"unexpected {extra}")
    for rel in sorted(files_a & files_b):
        if (a / rel).read_bytes() != (b / rel).read_bytes():
            problems.append(f"differs {rel}")
    for line in problems:
        print(line, file=sys.stderr)
    return len(problems)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jar", type=Path, default=DEFAULT_JAR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--resources", type=Path, default=DEFAULT_RES)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    if args.check:
        scratch = Path(tempfile.mkdtemp(prefix="mekanismtools-check-"))
        try:
            census = generate(args.jar, scratch / "content", args.resources)
            problems = compare(ROOT / "content", scratch / "content")
            committed = json.loads((ROOT / "tools/items.json").read_text())
            if committed != census:
                problems += 1
                print("tools/items.json is stale", file=sys.stderr)
        finally:
            shutil.rmtree(scratch, ignore_errors=True)
        if problems:
            print(f"content tree differs from the jar in {problems} place(s)", file=sys.stderr)
            return 1
        print("content tree matches the jar census")
    else:
        census = generate(args.jar, args.out, args.resources)
        (ROOT / "tools/items.json").write_text(
            json.dumps(census, indent=2, sort_keys=True) + "\n")
        print(json.dumps(census["counts"], sort_keys=True))
        print("skipped recipes: " + ", ".join(
            Path(p).relative_to("data/mekanismtools/recipe").as_posix()
            for p in census["skipped_recipes"]))

    rust = rust_census(ROOT / "mixins/mekanismtools/runtime.rs")
    plan = [i["id"] for i in census["items"]]
    if rust != plan:
        print(f"Rust ITEMS ({len(rust)}) differs from the jar census ({len(plan)}):",
              file=sys.stderr)
        for name in sorted(set(rust) ^ set(plan)):
            print(f"  {name}", file=sys.stderr)
        return 1
    print(f"Rust census: {len(rust)} item ids match the jar")
    return 0


if __name__ == "__main__":
    sys.exit(main())
