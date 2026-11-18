#!/usr/bin/env bash
# In-game check for Mekanism: Tools slice 1 (content, data tier): 72 items
# declared from 26.3 vanilla templates, the jar's assets, lang, tags and the
# recipes the port can fill.
#
# TRANSPORT CHANGED 2026-11-18, ASSERTIONS UNCHANGED. This scenario was written
# for the retired 0.1.0 `.hnmod` bundle, which loaded a separate `content/`
# folder with `--dev-mod`. A 0.2.0 package is one flat `.hmod` that the launcher
# compiles INTO the client, so there is no dev-mod folder to name:
#
#   horizon-launcher native-build ports/mekanismtools --instance <i> --trust-native-code
#   GAME=<that instance's horizon-client> tools/e2e.sh
#
# The 0.1.0 run (PASS + EXIT:0) and its SELFTEST run (FAIL + EXIT:1) stay the
# behaviour's evidence, in ports/_shared/evidence/mekanismtools/; no 0.2.0 run
# exists in this environment because `horizon-launcher` is not installed here
# (notes.md, "Migration to the SDK format" → gaps).
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
# CONTROL_GAME=<an unmodified build of the same Horizon revision> adds a first
# leg where the 72 ids must be unknown: that is the negative control for the
# package itself (the retired `tools/hmod-load.sh` did it with a shared game and
# `--dev-mod`; a native package cannot be loaded that way any more).
#
# The win screen: killing the ender dragon spawns the exit portal, and standing
# in it opens the WinScreen, which swallows every click (the first armour run
# died there) and performs a respawn in the Overworld when closed. The harness
# therefore never kills the dragon - it freezes it (`NoAI`) and moves it 4 km
# away - and every input phase goes through `ensure_playing`, which names and
# closes a stray screen, puts the player back in the arena if the close
# respawned them, and hard-fails instead of clicking into a screen.
set -uo pipefail
export LC_ALL=C
# Every line goes to stderr, which is not buffered when redirected: a run that
# is killed still leaves its transcript in the log.
exec 1>&2

CLONE=/home/adlf/Desktop/all_the_mods_10_rust_rewrite
PORT=$CLONE/ports/mekanismtools
# The control client is protocol-compatible per Horizon revision; override CTL
# with the one built from the same SDK build as GAME if a run says otherwise.
CTL=${CTL:-$CLONE/ports/_shared/bin/horizon-1d63e0a5/horizon-ctl}
# A 0.2.0 package is compiled into the client by the launcher, so GAME must be
# the `horizon-client` the launcher built WITH this package; there is no folder
# to load instead. Empty means "not runnable here", never "use something else".
GAME=${GAME:-}
# Optional: an unmodified build of the same revision, where the ids are unknown.
CONTROL_GAME=${CONTROL_GAME:-}
RES=${RES:-${HORIZON_RES:-/home/adlf/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/mekanismtools-e2e.sock}
CENSUS=$PORT/tools/items.json
SELFTEST=${SELFTEST:-0}
KEEP=${KEEP:-0}
WORLD=MekanismToolsE2E
CONTROL_WORLD=MekanismToolsControl

[ -n "$GAME" ] || {
    echo "no GAME: a native .hmod is compiled into the client by the launcher, so this scenario needs" >&2
    echo "  horizon-launcher native-build ports/mekanismtools --instance <i> --trust-native-code" >&2
    echo "  GAME=<that instance's horizon-client> tools/e2e.sh" >&2
    echo "horizon-launcher is not installed in this environment; no in-game claim is made (notes.md)." >&2
    exit 64
}
[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/horizon-mod.toml" ] || { echo "missing package manifest: $PORT/horizon-mod.toml" >&2; exit 1; }
[ -f "$PORT/mekanismtools.hmod" ] || { echo "missing delivered package: $PORT/mekanismtools.hmod" >&2; exit 1; }
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
screen_now() { ctl state | jq -r '.screen // "unknown"'; }
# The open screen's name and buttons, so a failure names what swallowed the
# click instead of only naming the command that lost it.
screen_detail() {
    ctl screen 2>/dev/null | jq -c '{screen:(.screen // .name // "?"), buttons:[.buttons[]? | (.label // .text // "?")]}' 2>/dev/null \
        || echo "unreadable"
}
# An open screen swallows every click: `use-item` answers "the <screen> screen
# is open; close it first" only after the input is gone. An open screen is
# therefore a hard error here, never a silent miss.
assert_playing() { # what the next input is for
    local screen
    screen=$(screen_now)
    [ "$screen" = "playing" ] \
        || fail "a '$screen' screen is open before $1, so the next input would be swallowed (screen: $(screen_detail))"
}
# Closing the win screen performs a remote respawn (the Overworld), so after a
# close the player is put back in the arena and the floor is re-verified.
back_to_arena() { # why
    local dim floor
    dim=$(ctl state | jq -r '.dimension')
    if [ "$dim" != "minecraft:the_end" ]; then
        echo "  closing the screen left the player in $dim ($1); returning to the End arena"
        for _ in 1 2 3; do
            end "tp @s 0.5 80 2.5"
            ctl wait 20 >/dev/null
            dim=$(ctl state | jq -r '.dimension')
            [ "$dim" = "minecraft:the_end" ] && break
            ctl wait-ready 60 >/dev/null
        done
        [ "$dim" = "minecraft:the_end" ] \
            || fail "the player did not return to The End after closing a screen (dimension: $dim)"
        ctl tp 0.5 80 2.5 >/dev/null
        ctl wait 20 >/dev/null
    fi
    floor=$(ctl block 0 79 0 | jq -r '.block')
    [ "$floor" = "minecraft:stone" ] \
        || fail "the arena floor at 0,79,0 is '$floor' after closing a screen, not stone"
}
# Close a stray screen (the win screen included) and require the game back.
ensure_playing() { # what the next input is for
    local screen attempt
    screen=$(screen_now)
    [ "$screen" = "playing" ] && return 0
    for attempt in 1 2 3; do
        echo "  screen '$screen' is open before $1: closing it (attempt $attempt, $(screen_detail))"
        case "$screen" in
            dead) ctl respawn >/dev/null 2>&1 || true ;;
            *) ctl close >/dev/null 2>&1 || true ;;
        esac
        ctl wait 5 >/dev/null
        screen=$(screen_now)
        [ "$screen" = "playing" ] && break
    done
    assert_playing "$1"
    back_to_arena "$1"
}

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

# The negative control: the SAME scenario's first assertion on a build without
# this package. Every id must be unknown there, so the main run cannot pass
# vacuously. It replaces the retired `tools/hmod-load.sh`, whose shared-game
# `--dev-mod` route no longer exists for a native package.
control_leg() {
    local real_game=$GAME held
    [ -x "$CONTROL_GAME" ] || fail "missing CONTROL_GAME: $CONTROL_GAME"
    echo "== control: an unmodified build must not know these ids ($CONTROL_GAME) =="
    GAME=$CONTROL_GAME
    rm -f "$SOCK"
    "$CTL" --socket "$SOCK" launch \
        --game "$GAME" --world "$CONTROL_WORLD" --seed 20261106 --creative --offscreen --wait \
        --game-dir "$SCRATCH/game" --resources "$RES"
    ctl wait-ready 180 >/dev/null
    ctl command "gamemode creative @s" >/dev/null
    ctl command "clear @s" >/dev/null
    ctl give mekanismtools:steel_pickaxe 1 >/dev/null 2>&1 || true
    ctl give mekanismtools:steel_helmet 1 >/dev/null 2>&1 || true
    ctl wait 6 >/dev/null
    held=$(count_item "mekanismtools:steel_pickaxe")
    [ "$held" = 0 ] || fail "the control game holds $held steel pickaxes, so the item did not come from this package"
    held=$(count_item "mekanismtools:steel_helmet")
    [ "$held" = 0 ] || fail "the control game holds $held steel helmets, so the item did not come from this package"
    echo "  without the package: both gives were refused, the inventory is empty"
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    GAME=$real_game
}

launch() { # world
    rm -f "$SOCK"
    # No `--dev-mod`: the package is inside this client (the launcher compiled it
    # in), so the content can only come from it.
    "$CTL" --socket "$SOCK" launch \
        --game "$GAME" --world "$1" --seed 20261106 --creative --offscreen --wait \
        --game-dir "$SCRATCH/game" --resources "$RES"
    ctl wait-ready 180 >/dev/null
    # The End is the only empty, floor-able level here; every fill names the
    # dimension explicitly and the arena is verified before anything is tested.
    end "forceload add -12 -12 20 12"
    dim=""
    for _ in 1 2 3; do
        end "tp @s 0.5 80 2.5"
        ctl wait 20 >/dev/null
        dim=$(ctl state | jq -r '.dimension')
        echo "  dimension after the teleport: $dim"
        [ "$dim" = "minecraft:the_end" ] && break
        ctl wait-ready 60 >/dev/null
    done
    [ "$dim" = "minecraft:the_end" ] || fail "the player did not reach The End (dimension: $dim)"
    ctl wait-ready 120 >/dev/null
    ctl wait 20 >/dev/null
    floor=""; cell=""
    for _ in 1 2 3; do
        end "fill -12 79 -12 20 79 12 minecraft:stone"
        end "fill -12 80 -12 20 88 12 minecraft:air"
        end "setblock 0 80 0 minecraft:air"
        ctl wait 10 >/dev/null
        floor=$(ctl block 0 79 0 | jq -r '.block')
        cell=$(ctl block 0 80 0 | jq -r '.block')
        echo "  arena: floor(0,79,0)=$floor summon-cell(0,80,0)=$cell"
        [ "$floor" = "minecraft:stone" ] && [ "$cell" = "minecraft:air" ] && break
        ctl wait 20 >/dev/null
    done
    # A mob summoned into a solid block suffocates for 1 hp per 10 ticks and
    # poisons every health reading, so this is a hard stop, not a warning.
    [ "$floor" = "minecraft:stone" ] || fail "the arena floor at 0,79,0 is '$floor', not stone"
    [ "$cell" = "minecraft:air" ] || fail "the summon cell at 0,80,0 is '$cell', not air"
    # The ambient End mobs go, but the dragon is frozen, not killed: its death
    # spawns the exit portal whose WinScreen swallows every later click (and a
    # `close` on it respawns the player in the Overworld). NoAI + 4 km away
    # keeps it from attacking without ever arming that screen.
    end "data merge entity @e[type=minecraft:ender_dragon,limit=1] {NoAI:1b,Silent:1b}"
    end "tp @e[type=minecraft:ender_dragon,limit=1] 4096 128 4096"
    end "kill @e[type=minecraft:end_crystal]"
    end "kill @e[type=minecraft:enderman]"
    end "kill @e[type=minecraft:item]"
    ctl wait 10 >/dev/null
    dragons=$(ctl entities 64 minecraft:ender_dragon | jq -c '[.entities[] | select(.type=="minecraft:ender_dragon") | {id,position}]')
    echo "  ender dragons within 64 blocks after the neutralisation: $dragons"
    [ "$dragons" = "[]" ] \
        || fail "an ender dragon is still within 64 blocks ($dragons); the win screen would poison the run"
    ctl close >/dev/null 2>&1 || true
    ctl wait 5 >/dev/null
    end "difficulty easy"
    end "tp @s 0.5 80 2.5"
    ctl tp 0.5 80 2.5 >/dev/null
    ctl wait 40 >/dev/null
    echo "  standing at $(ctl state | jq -c '{dimension,position:.player.position,screen}')"
    ensure_playing "the 72 gives"
}

say "launch (offscreen, creative, the launcher-built game)"
if [ -n "$CONTROL_GAME" ]; then
    control_leg
fi
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
ensure_playing "the armour phase"
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
    ctl wait 3 >/dev/null
    ctl select "mekanismtools:$id" >/dev/null || fail "cannot select mekanismtools:$id"
    ctl wait 3 >/dev/null
    got=$(armour_item "$slot")
    for attempt in 1 2; do
        ensure_playing "the equip of mekanismtools:$id"
        reply=$(ctl use-item) || fail "use-item failed for mekanismtools:$id: $reply"
        ctl wait 5 >/dev/null
        got=$(armour_item "$slot")
        [ "$got" = "mekanismtools:$id" ] && break
        echo "  $id: attempt $attempt read '$(ctl inventory | jq -c '[.armor[] | {part,item}]')' after $(echo "$reply" | jq -c '{ok,inventory_change,error}')"
    done
    [ "$got" = "mekanismtools:$id" ] \
        || fail "$id did not equip into the $part slot (got '$got'; armour $(ctl inventory | jq -c '[.armor[] | {part,item}]'))"
    echo "  $id -> $part"
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
    ensure_playing "the selftest equip"
    ctl use-item >/dev/null
    ctl wait 3 >/dev/null
    got=$(armour_item 1)
    [ "$got" = "mekanismtools:steel_chestplate" ] \
        || fail "SELFTEST: the chest slot reads '$got' after a stick, not the deliberately wrong 'mekanismtools:steel_chestplate'; the equip read-back is live (this exit 1 is the proof)"
    echo "SELFTEST unexpectedly matched the false equip"
fi

# -------------------------------------------------------------------- attack
say "a steel sword hits harder than a stick (attack differential)"
ensure_playing "the attack differential"
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
jq -en --arg s "$SWORD_HIT" '($s|tonumber) >= 3' >/dev/null \
    || fail "the steel sword dealt $SWORD_HIT damage; a diamond-template sword must clear 3"
jq -en --arg k "$STICK_HIT" '($k|tonumber) <= 2' >/dev/null \
    || fail "the stick dealt $STICK_HIT damage; an unarmed swing must stay at or below 2"
jq -en --arg s "$SWORD_HIT" --arg k "$STICK_HIT" '($s|tonumber) > ($k|tonumber)' >/dev/null \
    || fail "the steel sword dealt $SWORD_HIT and the stick $STICK_HIT: the sword must hit harder"
echo "the steel sword out-damages the stick ($SWORD_HIT vs $STICK_HIT)"

# -------------------------------------------------------------------- mining
say "a steel pickaxe breaks stone in the 16-tick budget and wears by 1"
ensure_playing "the pickaxe on stone"
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
[ "$(echo "$slow" | jq -r '.error // empty')" = "timed out before the block broke" ] \
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
ensure_playing "the tag checks"
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
ensure_playing "the recipe check"
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
