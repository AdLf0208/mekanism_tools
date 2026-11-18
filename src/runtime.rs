// Mekanism: Tools for Horizon — the carried item census (pure).
//
// Ported from Mekanism: Tools 10.7.19.85 (mekanism/Mekanism, MIT) for
// Minecraft Java 26.3 on Horizon `1d63e0a5`. This is a clean-room rewrite: the
// jar's own data files were read (item models, recipes, tags, lang) and its
// Java was not.
//
// This is a **data-tier** port, so the bundle has no injection: the 72 items
// are declared in `../content` from 26.3 vanilla item templates. This module
// spells out the families, the template map, the armour equipment ids and the
// paxel rule shape the content generator writes, so the census is testable
// without the game.
//
// Evidence for each choice:
//   * a tool's tier is the jar's own block tag
//     `data/mekanismtools/tags/block/incorrect_for_<material>_tool.json`
//     (lapis → stone, bronze/osmium → iron, glowstone/steel → diamond,
//     obsidian → netherite);
//   * a paxel is pickaxe + axe + shovel upstream, so its `minecraft:tool`
//     component unions the three `mineable` tags at the template's own speed;
//   * an armour piece takes the material class with the nearest documented
//     defence total (see `notes.md`, "Template map and deviations").

#[cfg(test)]
mod tests {
    /// `(material, tool tier, armour template material)`, from the jar's
    /// `incorrect_for_<material>_tool` tags and the wiki's defence totals.
    pub const MATERIALS: [(&str, &str, &str); 6] = [
        ("bronze", "iron", "diamond"),
        ("lapis_lazuli", "stone", "golden"),
        ("osmium", "iron", "diamond"),
        ("refined_glowstone", "diamond", "diamond"),
        ("refined_obsidian", "netherite", "netherite"),
        ("steel", "diamond", "diamond"),
    ];

    /// The jar's tool kinds (`ToolsItems`, one family per material).
    pub const TOOL_KINDS: [&str; 7] = [
        "axe", "hoe", "paxel", "pickaxe", "shield", "shovel", "sword",
    ];

    /// Armour slots and the equipment slot each one goes in.
    pub const ARMOUR_SLOTS: [(&str, &str); 4] = [
        ("helmet", "head"),
        ("chestplate", "chest"),
        ("leggings", "legs"),
        ("boots", "feet"),
    ];

    /// The vanilla paxels: `(item prefix, vanilla material)`.
    pub const VANILLA_PAXELS: [(&str, &str); 6] = [
        ("wood", "wooden"),
        ("stone", "stone"),
        ("iron", "iron"),
        ("gold", "golden"),
        ("diamond", "diamond"),
        ("netherite", "netherite"),
    ];

    /// The jar's `incorrect_for_<material>_tool` block tags (carried by the
    /// content mod), i.e. the harvest tier of each material's tools.
    pub const INCORRECT_FOR: [(&str, &str); 6] = [
        ("bronze", "#minecraft:incorrect_for_iron_tool"),
        ("lapis_lazuli", "#minecraft:incorrect_for_stone_tool"),
        ("osmium", "#minecraft:incorrect_for_iron_tool"),
        ("refined_glowstone", "#minecraft:incorrect_for_diamond_tool"),
        (
            "refined_obsidian",
            "#minecraft:incorrect_for_netherite_tool",
        ),
        ("steel", "#minecraft:incorrect_for_diamond_tool"),
    ];

    /// Every id the jar registers, in the generator's order (family by family).
    pub const ITEMS: [&str; 72] = [
        "bronze_axe",
        "bronze_hoe",
        "bronze_paxel",
        "bronze_pickaxe",
        "bronze_shield",
        "bronze_shovel",
        "bronze_sword",
        "bronze_helmet",
        "bronze_chestplate",
        "bronze_leggings",
        "bronze_boots",
        "lapis_lazuli_axe",
        "lapis_lazuli_hoe",
        "lapis_lazuli_paxel",
        "lapis_lazuli_pickaxe",
        "lapis_lazuli_shield",
        "lapis_lazuli_shovel",
        "lapis_lazuli_sword",
        "lapis_lazuli_helmet",
        "lapis_lazuli_chestplate",
        "lapis_lazuli_leggings",
        "lapis_lazuli_boots",
        "osmium_axe",
        "osmium_hoe",
        "osmium_paxel",
        "osmium_pickaxe",
        "osmium_shield",
        "osmium_shovel",
        "osmium_sword",
        "osmium_helmet",
        "osmium_chestplate",
        "osmium_leggings",
        "osmium_boots",
        "refined_glowstone_axe",
        "refined_glowstone_hoe",
        "refined_glowstone_paxel",
        "refined_glowstone_pickaxe",
        "refined_glowstone_shield",
        "refined_glowstone_shovel",
        "refined_glowstone_sword",
        "refined_glowstone_helmet",
        "refined_glowstone_chestplate",
        "refined_glowstone_leggings",
        "refined_glowstone_boots",
        "refined_obsidian_axe",
        "refined_obsidian_hoe",
        "refined_obsidian_paxel",
        "refined_obsidian_pickaxe",
        "refined_obsidian_shield",
        "refined_obsidian_shovel",
        "refined_obsidian_sword",
        "refined_obsidian_helmet",
        "refined_obsidian_chestplate",
        "refined_obsidian_leggings",
        "refined_obsidian_boots",
        "steel_axe",
        "steel_hoe",
        "steel_paxel",
        "steel_pickaxe",
        "steel_shield",
        "steel_shovel",
        "steel_sword",
        "steel_helmet",
        "steel_chestplate",
        "steel_leggings",
        "steel_boots",
        "wood_paxel",
        "stone_paxel",
        "iron_paxel",
        "gold_paxel",
        "diamond_paxel",
        "netherite_paxel",
    ];

    /// The template item a carried item copies: one vanilla item of the same
    /// kind at the material's own tier.
    pub fn template_for(material: &str, kind: &str) -> Option<String> {
        let (_, tier, armour) = MATERIALS.iter().find(|(m, _, _)| *m == material)?;
        Some(match kind {
            "shield" => "minecraft:shield".to_owned(),
            "paxel" => format!("minecraft:{tier}_pickaxe"),
            "helmet" | "chestplate" | "leggings" | "boots" => {
                format!("minecraft:{armour}_{kind}")
            }
            _ => format!("minecraft:{tier}_{kind}"),
        })
    }

    /// The equipment asset a modded armour piece names, so the worn layer is
    /// the mod's own (`assets/mekanismtools/equipment/<material>.json`).
    pub fn equipment_id(material: &str) -> String {
        format!("mekanismtools:{material}")
    }

    /// A paxel's `minecraft:tool.rules`: the material gate first (no drops),
    /// then the pickaxe, axe and shovel `mineable` tags at the template's own
    /// speed, since a paxel is all three tools upstream.
    pub fn paxel_rules(incorrect_for: &str, speed: f32) -> Vec<(String, bool, Option<f32>)> {
        let mut rules = vec![(incorrect_for.to_owned(), false, None)];
        for tag in ["pickaxe", "axe", "shovel"] {
            rules.push((format!("#minecraft:mineable/{tag}"), true, Some(speed)));
        }
        rules
    }

    /// The census built from the tables, in the generator's order.
    fn ids() -> Vec<String> {
        let mut out = Vec::new();
        for (material, _, _) in MATERIALS {
            for kind in TOOL_KINDS {
                out.push(format!("{material}_{kind}"));
            }
            for (slot, _) in ARMOUR_SLOTS {
                out.push(format!("{material}_{slot}"));
            }
        }
        for (prefix, _) in VANILLA_PAXELS {
            out.push(format!("{prefix}_paxel"));
        }
        out
    }

    #[test]
    fn the_census_is_72_unique_items_in_generator_order() {
        let built = ids();
        assert_eq!(built.len(), 72);
        assert_eq!(built, ITEMS, "ITEMS must be the table-derived census");
        let unique: std::collections::BTreeSet<_> = ITEMS.iter().collect();
        assert_eq!(unique.len(), ITEMS.len(), "duplicate item id");
    }

    #[test]
    fn every_material_has_all_seven_tools_and_all_four_armour_slots() {
        for (material, _, _) in MATERIALS {
            for kind in TOOL_KINDS {
                let id = format!("{material}_{kind}");
                assert!(ITEMS.contains(&id.as_str()), "{id} is missing");
            }
            for (slot, _) in ARMOUR_SLOTS {
                let id = format!("{material}_{slot}");
                assert!(ITEMS.contains(&id.as_str()), "{id} is missing");
            }
        }
    }

    #[test]
    fn the_vanilla_paxels_are_the_six_vanilla_tiers() {
        let paxels: Vec<_> = ITEMS
            .iter()
            .filter(|id| id.ends_with("_paxel"))
            .filter(|id| VANILLA_PAXELS.iter().any(|(p, _)| id.starts_with(p)))
            .copied()
            .collect();
        assert_eq!(paxels.len(), 6, "exactly six vanilla paxels");
        for (prefix, _) in VANILLA_PAXELS {
            assert!(paxels.contains(&format!("{prefix}_paxel").as_str()));
        }
    }

    #[test]
    fn a_tool_takes_the_template_of_its_own_tier() {
        assert_eq!(
            template_for("lapis_lazuli", "pickaxe").unwrap(),
            "minecraft:stone_pickaxe"
        );
        assert_eq!(
            template_for("bronze", "sword").unwrap(),
            "minecraft:iron_sword"
        );
        assert_eq!(template_for("osmium", "axe").unwrap(), "minecraft:iron_axe");
        assert_eq!(
            template_for("steel", "sword").unwrap(),
            "minecraft:diamond_sword"
        );
        assert_eq!(
            template_for("refined_glowstone", "pickaxe").unwrap(),
            "minecraft:diamond_pickaxe"
        );
        assert_eq!(
            template_for("refined_obsidian", "shovel").unwrap(),
            "minecraft:netherite_shovel"
        );
        assert_eq!(template_for("steel", "shield").unwrap(), "minecraft:shield");
        assert_eq!(
            template_for("steel", "paxel").unwrap(),
            "minecraft:diamond_pickaxe"
        );
        assert_eq!(template_for("iron", "nope"), None);
    }

    #[test]
    fn armour_takes_the_documented_class_and_its_own_equipment_asset() {
        assert_eq!(
            template_for("lapis_lazuli", "helmet").unwrap(),
            "minecraft:golden_helmet"
        );
        assert_eq!(
            template_for("steel", "chestplate").unwrap(),
            "minecraft:diamond_chestplate"
        );
        assert_eq!(
            template_for("refined_obsidian", "leggings").unwrap(),
            "minecraft:netherite_leggings"
        );
        assert_eq!(equipment_id("osmium"), "mekanismtools:osmium");
        for (material, _, _) in MATERIALS {
            assert_eq!(equipment_id(material), format!("mekanismtools:{material}"));
        }
    }

    #[test]
    fn the_armour_slots_are_the_four_equipment_parts() {
        let parts: Vec<_> = ARMOUR_SLOTS.iter().map(|(_, part)| *part).collect();
        assert_eq!(parts, ["head", "chest", "legs", "feet"]);
    }

    #[test]
    fn a_paxel_unions_pickaxe_axe_and_shovel_at_one_speed() {
        let rules = paxel_rules("#mekanismtools:incorrect_for_steel_tool", 8.0);
        assert_eq!(rules.len(), 4);
        assert_eq!(
            rules[0],
            (
                "#mekanismtools:incorrect_for_steel_tool".to_owned(),
                false,
                None
            )
        );
        let tags: Vec<_> = rules[1..].iter().map(|(tag, _, _)| tag.as_str()).collect();
        assert_eq!(
            tags,
            [
                "#minecraft:mineable/pickaxe",
                "#minecraft:mineable/axe",
                "#minecraft:mineable/shovel"
            ]
        );
        for (_, correct, speed) in &rules[1..] {
            assert!(correct, "the three mining rules are correct for drops");
            assert_eq!(*speed, Some(8.0), "they keep the template's speed");
        }
    }

    #[test]
    fn the_materials_carry_the_jars_harvest_tiers() {
        let gate = |material: &str| {
            INCORRECT_FOR
                .iter()
                .find(|(m, _)| *m == material)
                .map(|(_, tag)| *tag)
                .unwrap()
        };
        assert_eq!(gate("lapis_lazuli"), "#minecraft:incorrect_for_stone_tool");
        assert_eq!(gate("bronze"), "#minecraft:incorrect_for_iron_tool");
        assert_eq!(gate("osmium"), "#minecraft:incorrect_for_iron_tool");
        assert_eq!(
            gate("refined_glowstone"),
            "#minecraft:incorrect_for_diamond_tool"
        );
        assert_eq!(gate("steel"), "#minecraft:incorrect_for_diamond_tool");
        assert_eq!(
            gate("refined_obsidian"),
            "#minecraft:incorrect_for_netherite_tool"
        );
        assert_eq!(INCORRECT_FOR.len(), MATERIALS.len());
    }
}
