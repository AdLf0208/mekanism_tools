#!/usr/bin/env bash
# Prove the delivered package (content/mekanismtools.hmod) loads on a real
# game: the shared, unmodded 1d63e0a5 game with `--dev-mod <the .hmod>` must
# register the items and their behaviour. A second launch WITHOUT --dev-mod is
# the negative control: the same ids must be unknown there, so the check cannot
# pass vacuously.
set -uo pipefail
export LC_ALL=C

CLONE=${CAMPAIGN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
PIN_BIN=$CLONE/ports/_shared/bin/horizon-1d63e0a5
CTL=${CTL:-$PIN_BIN/horizon-ctl}
GAME=${GAME:-$PIN_BIN/horizon-client}
HMOD=${HMOD:-$CLONE/ports/mekanismtools/content/mekanismtools.hmod}
RES=${RES:-${HORIZON_RES:-$HOME/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/mekanismtools-hmod-load.sock}
KEEP=${KEEP:-0}

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -f "$HMOD" ] || { echo "missing package: $HMOD" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/mekanismtools-hmod-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")" "$XDG_CONFIG_HOME"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
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

launch() { # world [extra args...]
    local world=$1; shift
    rm -f "$SOCK"
    "$CTL" --socket "$SOCK" launch \
        --game "$GAME" --world "$world" --seed 20261106 --creative --headless --wait \
        --game-dir "$SCRATCH/game" --resources "$RES" "$@" >/dev/null
    ctl wait-ready 120 >/dev/null
    ctl command "execute in minecraft:the_end run tp @s 0.5 80 2.5" >/dev/null
    ctl wait 20 >/dev/null
}
CASES=(
    "mekanismtools:steel_pickaxe"
    "mekanismtools:lapis_lazuli_helmet"
    "mekanismtools:netherite_paxel"
    "mekanismtools:bronze_shield"
)

echo "== launch WITH the package (--dev-mod $HMOD) =="
launch MekanismToolsHmod --dev-mod "$HMOD"
ctl command "execute in minecraft:the_end run fill -4 79 -4 8 79 8 minecraft:stone" >/dev/null
ctl command "execute in minecraft:the_end run fill -4 80 -4 8 88 8 minecraft:air" >/dev/null
ctl wait 4 >/dev/null
ctl tp 0.5 80 2.5 >/dev/null
ctl wait 10 >/dev/null
for id in "${CASES[@]}"; do
    ctl command "clear @s" >/dev/null
    ctl give "$id" 1 >/dev/null || fail "the package did not register $id"
    ctl wait 3 >/dev/null
    got=$(ctl inventory | jq -r --arg i "$id" '.counts[$i] // 0')
    echo "item $id = $got"
    [ "$got" -ge 1 ] || fail "the package did not register $id"
done
echo "-- the armour piece equips from the delivered package"
ctl command "clear @s" >/dev/null
ctl give mekanismtools:lapis_lazuli_helmet 1 >/dev/null
ctl wait 2 >/dev/null
ctl select mekanismtools:lapis_lazuli_helmet >/dev/null
ctl wait 2 >/dev/null
ctl use-item >/dev/null
ctl wait 3 >/dev/null
head=$(ctl inventory | jq -r '.armor[0].item // "empty"')
echo "head slot = $head"
[ "$head" = "mekanismtools:lapis_lazuli_helmet" ] || fail "the package's helmet did not equip (head: $head)"
echo "-- the paxel breaks a log from the delivered package"
ctl command "gamemode survival @s" >/dev/null
ctl command "clear @s" >/dev/null
ctl give mekanismtools:netherite_paxel 1 >/dev/null
ctl wait 2 >/dev/null
ctl select mekanismtools:netherite_paxel >/dev/null
ctl wait 2 >/dev/null
ctl setblock 1 80 0 minecraft:oak_log >/dev/null
ctl wait 2 >/dev/null
ctl look-at-block 1 80 0 >/dev/null
broken=$(ctl break 1 80 0 --timeout 0.8) || fail "the delivered paxel did not break the log: $broken"
echo "  paxel on a log: $(echo "$broken" | jq -c '{block,drops,ticks}')"
[ "$(echo "$broken" | jq -r '.block')" = "minecraft:air" ] || fail "the delivered paxel did not break the log: $broken"
ctl command "gamemode creative @s" >/dev/null
ctl quit >/dev/null 2>&1 || true
sleep 2

echo "== negative control: the SAME ids without --dev-mod =="
launch MekanismToolsHmodControl
for id in "${CASES[@]}"; do
    ctl command "clear @s" >/dev/null
    if ctl give "$id" 1 >/dev/null 2>&1; then
        fail "give $id succeeded without the package"
    fi
    got=$(ctl inventory | jq -r --arg i "$id" '.counts[$i] // 0')
    echo "control item $id = $got"
    [ "$got" -eq 0 ] || fail "$id is in the inventory without the package"
done
head=$(ctl inventory | jq -r '.armor[0].item // "empty"')
[ "$head" = "empty" ] || fail "an armour piece is worn without the package (head: $head)"
echo "control: all four ids are unknown without the package"

echo "PASS: the .hmod registers the four sampled items, its helmet equips and its paxel breaks a log; without it the same ids are refused"
