#!/usr/bin/env bash
set -euo pipefail

# mypy wrapper that prefers a project virtualenv and excludes common venv dirs
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Prefer project venv locations if available
if [ -x "$ROOT_DIR/.venv/bin/python" ]; then
  PY="$ROOT_DIR/.venv/bin/python"
elif [ -x "$ROOT_DIR/venv/bin/python" ]; then
  PY="$ROOT_DIR/venv/bin/python"
else
  PY="$(command -v python3 || command -v python)"
fi

echo "Using python: $PY"

# Directories (relative to ROOT_DIR) to ignore when searching for files
IGNORE_DIRS=(
  .venv
  venv
  .git
  tools
  unused
)

# Build find prune args from IGNORE_DIRS
FIND_PRUNES=()
for d in "${IGNORE_DIRS[@]}"; do
  FIND_PRUNES+=( -path "$ROOT_DIR/$d" -prune -o )
done

# Find Python files excluding the ignore dirs
mapfile -t FILES < <(find "$ROOT_DIR" "${FIND_PRUNES[@]}" -name '*.py' -print)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No Python files found to type check."
  exit 0
fi

"$PY" -m mypy --strict "${FILES[@]}"
