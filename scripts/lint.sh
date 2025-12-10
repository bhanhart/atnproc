#!/usr/bin/env bash
set -euo pipefail

# Lint wrapper that prefers a project virtualenv and excludes common venv dirs
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

# Find Python files excluding venv folders and .git
mapfile -t FILES < <(find "$ROOT_DIR" \
  -path "$ROOT_DIR/.venv" -prune -o \
  -path "$ROOT_DIR/venv" -prune -o \
  -path "$ROOT_DIR/.git" -prune -o \
  -name '*.py' -print)

if [ ${#FILES[@]} -eq 0 ]; then
  echo "No Python files found to lint."
  exit 0
fi

"$PY" -m pylint "${FILES[@]}"
