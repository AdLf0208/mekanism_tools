#!/usr/bin/env bash
# In-game check for Mekanism: Tools slice 1 (content, data tier): 72 items
# declared from 26.3 vanilla templates, the jar's assets, lang, tags and the
# recipes the port can fill.
#
# The End arena (stone floor at y=79); the player stands at 0.5/80/2.5.
#
# Default run (PASS + EXIT:0):
#   1. all 72 items are /give-able (two batches, the inventory holds 36);
#   2. the mod's creative tab `mekanismtools:all` lists exactly the 72 items in
#      the generator's order, and no other mekanismtools id is in any tab;
#   3. every one of the 24 armour pieces equips by right-click into its own
#      slot (head/chest/legs/feet) and reads back from `ctl inventory`;
#   4. a steel sword (diamond template) hits harder than a stick on a fresh
#      zombie, read from the attack reply's own before/after health - the
#      attack differential;
#   5. a steel pickaxe breaks stone in a 16-tick budget and drops cobblestone,
#      the held stack loses exactly 1 durability;
#   6. a steel paxel breaks an oak log inside the same 16-tick budget while the
#      steel pickaxe times out (the paxel's axe rule), and the paxel breaks
#      dirt inside an 8-tick budget (the shovel rule);
#   7. the item tags answer through `execute if items`: the pickaxe is in
#      `#minecraft:pickaxes`, the sword in `#minecraft:swords`, the helmet in
#      `#minecraft:head_armor`, and the pickaxe is NOT in `#minecraft:swords`;
#   8. 3 lapis + 2 sticks crafts a lapis pickaxe and 5 lapis a lapis helmet,
#      with four controls that stay empty (tools/craft_check.py);
#   9. unknown mekanismtools ids are refused by `give`.
#
# SELFTEST=1 flips one equip assertion after the loop (a stick must appear in
# the chest slot); it MUST exit non-zero, which proves the read-back is live.
# The no-`--dev-mod` control is tools/hmod-load.sh (the delivered .hmod).
set -uo pipefail
export LC_ALL=C
# Every line goes to stderr, which is not buffered when redirected: a run that
# is killed still leaves its transcript in the log.
exec 1>&2

CLONE=${CAMPAIGN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
PORT=$CLONE/ports/mekanismtools
CTL=${CTL:-$CLONE/ports/_shared/bin/horizon-1d63e0a5/horizon-ctl}
GAME=${GAME:-$CLONE/ports/_shared/bin/horizon-1d63e0a5/horizon-client}
RES=${RES:-${HORIZON_RES:-$HOME/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/mekanismtools-e2e.sock}
CENSUS=$PORT/tools/items.json
SELFTEST=${SELFTEST:-0}
KEEP=${KEEP:-0}
WORLD=MekanismToolsE2E

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/content/horizon-mod.toml" ] || { echo "missing content mod: $PORT/content" >&2; exit 1; }
[ -f "$CENSUS" ] || { echo "missing census: $CENSUS" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

ITEMS=()
mapfile -t ITEMS < <(jq -r '.items[].id' "$CENSUS")
COUNT=$(jq -r '.counts.items' "$CENSUS")
[ "${#ITEMS[@]}" -eq 72 ] || { echo "census has ${#ITEMS[@]} items, expected 72" >&2; exit 1; }
[ "$COUNT" -eq 72 ] || { echo "census counts.items is $COUNT, expected 72" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/mekanismtools-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
say() { echo "+ $*"; }
end() { ctl command "execute in minecraft:the_end run $1" >/dev/null; }
count_item() { ctl inventory | jq -r --arg i "$1" '.counts[$i] // 0'; }
held_item() { ctl inventory | jq -r '.held.item // "empty"'; }
held_damage() { ctl inventory | jq -r '.held.damage // 0'; }
armour_item() { ctl inventory | jq -r --argjson n "$1" '.armor[$n].item // "empty"'; }
zombie_id() { ctl entities | jq -r '[.entities[] | select(.type=="minecraft:zombie")][0].id // ""'; }

cleanup() {
    status=$?
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    [ "$KEEP" = 1 ] && echo "kept scratch: $SCRATCH" >&2
    [ "$KEEP" = 1 ] || rm -rf "$SCRATCH" 2>/dev/null || true
    echo "EXIT:$status"
    exit "$status"
}
trap cleanup EXIT

launch() { # world
    rm -f "$SOCK"
    "$CTL" --socket "$SOCK" launch \
        --game "$GAME" --world "$1" --seed 20261106 --creative --offscreen --wait \
        --game-dir "$SCRATCH/game" --resources "$RES" --dev-mod "$PORT/content"
    ctl wait-ready 180 >/dev/null
    end "forceload add -12 -12 20 12"
    end "tp @s 0.5 80 2.5"
    ctl wait-ready 120 >/dev/null
    end "fill -12 79 -12 20 79 12 minecraft:stone"
    end "fill -12 80 -12 20 88 12 minecraft:air"
    end "kill @e[type=!minecraft:player]"
    end "difficulty easy"
    end "gamerule doMobSpawning false"
    end "tp @s 0.5 80 2.5"
    ctl wait 40 >/dev/null
}

say "launch (offscreen, creative, content --dev-mod content/)"
launch "$WORLD"
echo "  standing at $(ctl state | jq -c '{dimension,pos:.player.position}')"

# ------------------------------------------------------------------ give all
say "all 72 items are give-able (two batches: 36 + 36)"
ctl command "clear @s" >/dev/null
for id in "${ITEMS[@]:0:36}"; do
    ctl give "mekanismtools:$id" 1 >/dev/null || fail "give mekanismtools:$id failed"
done
ctl wait 6 >/dev/null
for id in "${ITEMS[@]:0:36}"; do
    [ "$(count_item "mekanismtools:$id")" -ge 1 ] || fail "mekanismtools:$id is missing from the inventory"
done
ctl command "clear @s" >/dev/null
for id in "${ITEMS[@]:36}"; do
    ctl give "mekanismtools:$id" 1 >/dev/null || fail "give mekanismtools:$id failed"
done
ctl wait 6 >/dev/null
for id in "${ITEMS[@]:36}"; do
    [ "$(count_item "mekanismtools:$id")" -ge 1 ] || fail "mekanismtools:$id is missing from the inventory"
done
ctl command "clear @s" >/dev/null
echo "72/72 items are give-able"

# --------------------------------------------------------------- creative tab
say "the creative tab lists all 72 items in the generator's order"
CREATIVE=$(find "$SCRATCH/game/.horizon-cache/mod-content" -maxdepth 2 -name creative-inventory.json 2>/dev/null | head -1)
[ -n "$CREATIVE" ] || fail "no creative-inventory.json under $SCRATCH/game/.horizon-cache/mod-content"
python3 - "$CREATIVE" "$CENSUS" <<'PY' || fail "the creative tab check failed"
import json, re, sys
cache = json.load(open(sys.argv[1]))
census = json.load(open(sys.argv[2]))
want = ["mekanismtools:" + i["id"] for i in census["items"]]
tabs = [t for t in cache["tabs"] if t.get("id") == "mekanismtools:all"]
if len(tabs) != 1:
    raise SystemExit(f"expected one mekanismtools:all tab, found {len(tabs)}")
items = [m.group(1) for v in tabs[0]["items"] if (m := re.search(r'id:"([^"]+)"', v))]
if items != want:
    missing = [i for i in want if i not in items]
    extra = [i for i in items if i not in want]
    raise SystemExit(f"tab items differ: missing={missing} extra={extra}")
owned = set()
for tab in cache["tabs"]:
    for value in tab.get("items", []):
        found = re.search(r'id:"([^"]+)"', value)
        if found and found.group(1).startswith("mekanismtools:"):
            owned.add(found.group(1))
unknown = sorted(owned - set(want))
if unknown:
    raise SystemExit(f"creative inventory holds undeclared mekanismtools items: {unknown}")
print(f"creative tab mekanismtools:all lists all {len(items)} items in order")
PY
echo "creative tab lists all 72 items"

# -------------------------------------------------------------------- armour
say "all 24 armour pieces equip by right-click and read back"
while IFS=$'\t' read -r id part; do
    case "$part" in
        head) slot=0 ;;
        chest) slot=1 ;;
        legs) slot=2 ;;
        feet) slot=3 ;;
        *) fail "unknown armour part '$part' for $id" ;;
    esac
    ctl command "clear @s" >/dev/null
    ctl give "mekanismtools:$id" 1 >/dev/null || fail "cannot give mekanismtools:$id"
    ctl wait 2 >/dev/null
    ctl select "mekanismtools:$id" >/dev/null || fail "cannot select mekanismtools:$id"
    ctl wait 2 >/dev/null
    ctl use-item >/dev/null
    ctl wait 3 >/dev/null
    got=$(armour_item "$slot")
    [ "$got" = "mekanismtools:$id" ] || fail "$id equipped as '$got' in the $part slot"
done < <(jq -r '.items[] | select(.family=="armour") | [.id, .armour_slot] | @tsv' "$CENSUS")
arms=$(jq -r '[.items[] | select(.family=="armour")] | length' "$CENSUS")
[ "$arms" -eq 24 ] || fail "census has $arms armour pieces, expected 24"
echo "24/24 armour pieces equip into their own slot"

if [ "$SELFTEST" = 1 ]; then
    # A deliberately false expectation: a stick cannot fill the chest slot, so
    # this MUST fail. If it ever printed the echo, the equip read-back would be
    # vacuous.
    say "SELFTEST: a deliberately false equip assertion must fail the run"
    ctl command "clear @s" >/dev/null
    ctl give minecraft:stick 1 >/dev/null
    ctl wait 2 >/dev/null
    ctl select minecraft:stick >/dev/null
    ctl wait 2 >/dev/null
    ctl use-item >/dev/null
    ctl wait 3 >/dev/null
    got=$(armour_item 1)
    [ "$got" = "mekanismtools:steel_chestplate" ] \
        || fail "SELFTEST: the chest slot reads '$got' after a stick, not the deliberately wrong 'mekanismtools:steel_chestplate'; the equip read-back is live (this exit 1 is the proof)"
    echo "SELFTEST unexpectedly matched the false equip"
fi

# -------------------------------------------------------------------- attack
say "a steel sword hits harder than a stick (attack differential)"
ctl command "gamemode survival @s" >/dev/null
swing() { # item reply-file
    ctl command "kill @e[type=minecraft:zombie]" >/dev/null 2>&1
    ctl command "clear @s" >/dev/null
    ctl give "$1" 1 >/dev/null || return 1
    ctl wait 2 >/dev/null
    ctl select "$1" >/dev/null || return 1
    ctl wait 40 >/dev/null   # the attack cooldown, so the swing is not a tap
    ctl command "summon minecraft:zombie 0.5 80 0.5 {NoAI:1b,Silent:1b,PersistenceRequired:1b}" >/dev/null || return 1
    ctl wait 6 >/dev/null
    id=$(zombie_id)
    [ -n "$id" ] || return 1
    before=$(ctl entities | jq -r --arg i "$id" '(.entities[] | select((.id|tostring) == $i) | .health) // empty')
    [ -n "$before" ] || return 1
    ctl attack "$id" >"$2" || return 1
    # The client's mob health syncs a few ticks after the server applies the
    # hit, so the reply's own `health` (4 ticks) can still be the old value.
    ctl wait 12 >/dev/null
    after=$(ctl entities | jq -r --arg i "$id" '(.entities[] | select((.id|tostring) == $i) | .health) // empty')
    [ -n "$after" ] || return 1
    echo "  $1 -> $(jq -c '{hit,target,health_before,health,alive}' "$2") (id $id: $before -> $after)"
    [ "$(jq -r '.hit' "$2")" = "true" ] || return 1
    jq -n --argjson b "$before" --argjson a "$after" '{before:$b, after:$a, hit:($b - $a)}' >"$2.health"
    return 0
}
swing mekanismtools:steel_sword "$SCRATCH/sword.json" || fail "the steel sword swing failed"
swing minecraft:stick "$SCRATCH/stick.json" || fail "the stick swing failed"
SWORD_HIT=$(jq -r '.hit' "$SCRATCH/sword.json.health")
STICK_HIT=$(jq -r '.hit' "$SCRATCH/stick.json.health")
echo "  damage: steel_sword $SWORD_HIT, stick $STICK_HIT"
jq -en --arg s "$SWORD_HIT" --arg k "$STICK_HIT" '($s|tonumber) > ($k|tonumber)' >/dev/null \
    || fail "the steel sword dealt $SWORD_HIT and the stick $STICK_HIT: the sword must hit harder"
jq -en --arg s "$SWORD_HIT" '($s|tonumber) >= 1' >/dev/null || fail "the sword dealt no damage"
echo "the steel sword out-damages the stick ($SWORD_HIT vs $STICK_HIT)"

# -------------------------------------------------------------------- mining
say "a steel pickaxe breaks stone in the 16-tick budget and wears by 1"
ctl command "gamemode survival @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give mekanismtools:steel_pickaxe 1 >/dev/null
ctl wait 2 >/dev/null
ctl select mekanismtools:steel_pickaxe >/dev/null
ctl wait 2 >/dev/null
ctl tp 0.5 80 2.5 >/dev/null
ctl wait 6 >/dev/null
ctl setblock 1 80 0 minecraft:stone >/dev/null
ctl wait 2 >/dev/null
ctl look-at-block 1 80 0 >/dev/null
broken=$(ctl break 1 80 0 --timeout 0.8) || fail "the pickaxe did not break stone: $broken"
echo "  pickaxe on stone: $(echo "$broken" | jq -c '{block_before,block,drops,ticks}')"
[ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "the stone did not break: $broken"
[ "$(echo "$broken" | jq -r '.drops["minecraft:cobblestone"] // 0')" -ge 1 ] \
    || fail "the stone dropped no cobblestone: $broken"
[ "$(held_damage)" -eq 1 ] || fail "the pickaxe's damage is $(held_damage), expected 1 after one block"
echo "  held damage after one block: $(held_damage)"

say "the paxel's axe rule: paxel breaks a log in 16 ticks, the pickaxe times out"
ctl command "clear @s" >/dev/null
ctl give mekanismtools:steel_paxel 1 >/dev/null
ctl wait 2 >/dev/null
ctl select mekanismtools:steel_paxel >/dev/null
ctl wait 2 >/dev/null
ctl setblock 1 80 0 minecraft:oak_log >/dev/null
ctl wait 2 >/dev/null
ctl look-at-block 1 80 0 >/dev/null
paxel=$(ctl break 1 80 0 --timeout 0.8) || fail "the paxel did not break the log: $paxel"
echo "  paxel on a log: $(echo "$paxel" | jq -c '{block_before,block,drops,ticks}')"
[ "$(echo "$paxel" | jq -r '.block')" = "minecraft:air" ] || fail "the paxel did not break the log: $paxel"
[ "$(echo "$paxel" | jq -r '.drops["minecraft:oak_log"] // 0')" -ge 1 ] \
    || fail "the log dropped no oak_log: $paxel"

ctl command "clear @s" >/dev/null
ctl give mekanismtools:steel_pickaxe 1 >/dev/null
ctl wait 2 >/dev/null
ctl select mekanismtools:steel_pickaxe >/dev/null
ctl wait 2 >/dev/null
ctl setblock 1 80 0 minecraft:oak_log >/dev/null
ctl wait 2 >/dev/null
ctl look-at-block 1 80 0 >/dev/null
slow=$(ctl break 1 80 0 --timeout 0.8) || true
echo "  pickaxe on a log: $(echo "$slow" | jq -c '{block,error,ticks}')"
[ "$(echo "$slow" | jq -r '.block')" = "minecraft:oak_log" ] \
    || fail "the pickaxe broke the log inside 16 ticks, so the paxel differential proves nothing: $slow"
[ "$(ctl block 1 80 0 | jq -r '.block')" = "minecraft:oak_log" ] || fail "the log is gone after the pickaxe control"
echo "  the pickaxe left the log standing in the same 16-tick budget (the paxel's axe rule is what broke it)"

say "the paxel's shovel rule: dirt breaks inside an 8-tick budget"
ctl command "clear @s" >/dev/null
ctl give mekanismtools:steel_paxel 1 >/dev/null
ctl wait 2 >/dev/null
ctl select mekanismtools:steel_paxel >/dev/null
ctl wait 2 >/dev/null
ctl setblock 1 80 0 minecraft:dirt >/dev/null
ctl wait 2 >/dev/null
ctl look-at-block 1 80 0 >/dev/null
shovel=$(ctl break 1 80 0 --timeout 0.4) || fail "the paxel did not break dirt in 8 ticks: $shovel"
echo "  paxel on dirt: $(echo "$shovel" | jq -c '{block,drops,ticks}')"
[ "$(echo "$shovel" | jq -r '.block')" = "minecraft:air" ] || fail "the dirt did not break: $shovel"
ctl command "kill @e[type=minecraft:item]" >/dev/null 2>&1

# ---------------------------------------------------------------------- tags
say "the item tags answer through execute if items"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give mekanismtools:steel_pickaxe 1 >/dev/null
ctl wait 3 >/dev/null
ctl select mekanismtools:steel_pickaxe >/dev/null
ctl wait 2 >/dev/null
ctl command "execute if items entity @s hotbar.0 #minecraft:pickaxes run say TAG_PICKAXES" >/dev/null
ctl command "execute if items entity @s hotbar.0 #minecraft:swords run say TAG_PICK_AXE_TAG" >/dev/null
ctl command "clear @s" >/dev/null
ctl give mekanismtools:steel_sword 1 >/dev/null
ctl wait 3 >/dev/null
ctl select mekanismtools:steel_sword >/dev/null
ctl wait 2 >/dev/null
ctl command "execute if items entity @s hotbar.0 #minecraft:swords run say TAG_SWORDS" >/dev/null
ctl command "clear @s" >/dev/null
ctl give mekanismtools:steel_helmet 1 >/dev/null
ctl wait 3 >/dev/null
ctl select mekanismtools:steel_helmet >/dev/null
ctl wait 2 >/dev/null
ctl command "execute if items entity @s hotbar.0 #minecraft:head_armor run say TAG_HELMET" >/dev/null
ctl wait 8 >/dev/null
messages=$(ctl messages 40 | jq -r '.chat[]')
echo "$messages" | grep -Eq 'TAG_PICKAXES' || fail "the pickaxe is not in #minecraft:pickaxes (chat: $messages)"
echo "$messages" | grep -Eq 'TAG_SWORDS' || fail "the sword is not in #minecraft:swords (chat: $messages)"
echo "$messages" | grep -Eq 'TAG_HELMET' || fail "the helmet is not in #minecraft:head_armor (chat: $messages)"
echo "$messages" | grep -q 'TAG_PICK_AXE_TAG' && fail "the pickaxe matched #minecraft:swords, so the tag check is not discriminating"
echo "tags: pickaxe in #minecraft:pickaxes, sword in #minecraft:swords, helmet in #minecraft:head_armor, pickaxe not in swords"

# ------------------------------------------------------------------- recipes
say "craft the lapis recipes with four empty controls"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl command "tp @s 5.5 80 2.5" >/dev/null
end "setblock 6 80 2 minecraft:crafting_table"
ctl wait 5 >/dev/null
python3 "$PORT/tools/craft_check.py" "$SOCK" "$CTL" 6 80 2 || fail "the recipe check failed"
ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl wait 2 >/dev/null

# -------------------------------------------------------------- unknown ids
say "unknown mekanismtools ids are refused"
if ctl give mekanismtools:not_a_tool 1 >/dev/null 2>&1; then
    fail "give mekanismtools:not_a_tool succeeded"
fi
if ctl give mekanismtools:steel_paxel_extra 1 >/dev/null 2>&1; then
    fail "give mekanismtools:steel_paxel_extra succeeded"
fi
echo "unknown mekanismtools ids are refused"

ctl command "gamemode creative @s" >/dev/null
ctl command "clear @s" >/dev/null
echo "PASS: 72/72 items give, the creative tab lists all 72, 24/24 armour pieces equip into their own slot, the steel sword out-damages a stick, the pickaxe breaks stone and wears by 1, the paxel breaks a log while the pickaxe times out and breaks dirt in 8 ticks, the item tags answer, the lapis recipes craft with four empty controls, and unknown ids are refused"
