#!/usr/bin/env bash
# The offline ladder for this flat SDK package (mod API 0.2): fmt, the census
# tests, clippy and the content carry check. There is no game and no staging
# step — the package's code is compiled in place against `.horizon/sdk/`.
#
# Run it through the slot runner, from inside the port (`--port .`, trap 1 of
# the migration):
#
#   ports/tools/build-slot.sh run --job <job> --port . --step unit -- tools/unit.sh
#
# `cargo fmt --check`, never `--all`: `.horizon/sdk` is a path dependency, so
# `--all` reports the fetched SDK's own files (trap 4 of the recipe).
set -uo pipefail
export LC_ALL=C
PORT=$(cd "$(dirname "$0")/.." && pwd)
CLONE=/home/adlf/Desktop/all_the_mods_10_rust_rewrite
OUT=${EVIDENCE:-$CLONE/ports/_shared/evidence/mekanismtools}
mkdir -p "$OUT"
cd "$PORT" || exit 1
export CARGO_INCREMENTAL=0

echo "== fmt =="
cargo fmt --check >"$OUT/sdk-fmt.log" 2>&1
echo "fmt_exit=$?"

echo "== tests =="
cargo test --offline >"$OUT/sdk-test.log" 2>&1
echo "test_exit=$?"
grep -E '^(test result|running )' "$OUT/sdk-test.log" || true

echo "== clippy =="
cargo clippy --all-targets --offline -- -D warnings >"$OUT/sdk-clippy.log" 2>&1
echo "clippy_exit=$?"
echo "warning_lines=$(grep -cE '^(warning|error)' "$OUT/sdk-clippy.log" || true)"

echo "== content carry =="
python3 tools/gen_content.py --check >"$OUT/sdk-content-carry.log" 2>&1
echo "carry_exit=$?"
cat "$OUT/sdk-content-carry.log"
