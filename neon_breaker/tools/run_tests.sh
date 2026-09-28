#!/usr/bin/env bash
# Runs the Neon Breaker headless test suite.
#
#   GODOT=/path/to/godot ./tools/run_tests.sh
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "Не найден бинарник Godot ('$GODOT'). Укажите путь через переменную GODOT." >&2
	exit 2
fi

cd "$ROOT"

status=0
for scene in res://tests/test_runner.tscn res://tests/integration_runner.tscn; do
	echo "== $scene =="
	"$GODOT" --headless --path "$ROOT" "$scene" || status=1
done
exit "$status"
