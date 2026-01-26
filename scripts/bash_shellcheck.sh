#!/usr/bin/env bash
set -euo pipefail

# Check syntax of Bash scripts in the repo, excluding common venv and ignored dirs
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Directories (relative to ROOT_DIR) to ignore when searching for files
IGNORE_DIRS=(
  .venv
  venv
  .git
  skyguide
  example
  unused
)

# Build find prune args from IGNORE_DIRS
FIND_PRUNES=()
for d in "${IGNORE_DIRS[@]}"; do
  FIND_PRUNES+=( -path "$ROOT_DIR/$d" -prune -o )
done

echo "Searching for shell scripts under: $ROOT_DIR"

# Find files that end with .sh
mapfile -t SCRIPTS < <(find "$ROOT_DIR" "${FIND_PRUNES[@]}" -name '*.sh' -print 2>/dev/null || true)

# Files whose first line starts with #! and contains 'sh' or 'bash'
# shellcheck disable=SC2016
mapfile -t SHEBANG_FILES < <(find "$ROOT_DIR" "${FIND_PRUNES[@]}" -type f -print0 2>/dev/null |
  xargs -0 -n1 sh -c 'head -n1 "$0" 2>/dev/null | grep -E "^#!.*\b(sh|bash)\b" >/dev/null && printf "%s\n" "$0"' 2>/dev/null || true)

# Combine and deduplicate
ALL_FILES=()
declare -A seen
for f in "${SCRIPTS[@]}" "${SHEBANG_FILES[@]}"; do
  [ -z "$f" ] && continue
  if [ -z "${seen[$f]:-}" ]; then
    ALL_FILES+=("$f")
    seen[$f]=1
  fi
done

if [ ${#ALL_FILES[@]} -eq 0 ]; then
  echo "No shell scripts found to check."
  exit 0
fi

echo "Checking ${#ALL_FILES[@]} script(s) for syntax errors..."
failures=0
SYNTAX_ERRS=()
for script in "${ALL_FILES[@]}"; do
  tmp_err=$(mktemp)
  if ! bash -n "$script" 2>"$tmp_err"; then
    failures=$((failures+1))
    SYNTAX_ERRS+=("$script:$tmp_err")
    if [ "${VERBOSE:-0}" = "1" ]; then
      echo "SYNTAX ERROR in: $script"
      sed -n '1,200p' "$tmp_err"
    fi
  else
    rm -f "$tmp_err"
  fi
done

if [ $failures -ne 0 ]; then
  echo "Found $failures syntax error(s) in shell scripts."
  if [ "${VERBOSE:-0}" != "1" ]; then
    echo "Run with VERBOSE=1 to show details."
  else
    # print details already printed during the loop
    :
  fi
  # print summarized errors if not verbose
  if [ "${VERBOSE:-0}" != "1" ]; then
    for entry in "${SYNTAX_ERRS[@]}"; do
      script=${entry%%:*}
      errfile=${entry#*:}
      echo "${script}: $(sed -n '1p' "$errfile")"
      rm -f "$errfile"
    done
  fi
  exit 2
fi

echo "All checked shell scripts passed syntax check."

# ShellCheck integration
# By default run shellcheck if available. Set NO_SHELLCHECK=1 to skip.
if [ "${NO_SHELLCHECK:-0}" = "1" ]; then
  echo "Skipping shellcheck because NO_SHELLCHECK=1"
  exit 0
fi

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not found; skipping ShellCheck step"
  exit 0
fi

echo "Running ShellCheck on ${#ALL_FILES[@]} script(s)..."
sc_failures=0
SC_ISSUES=()
for script in "${ALL_FILES[@]}"; do
  if [ "${VERBOSE:-0}" = "1" ]; then
    echo "Checking ${script} ..."
  fi
  sc_tmp=$(mktemp)
  if ! shellcheck "$script" >"$sc_tmp" 2>&1; then
    sc_failures=$((sc_failures+1))
    SC_ISSUES+=("$script:$sc_tmp")
    if [ "${VERBOSE:-0}" = "1" ]; then
      echo "ShellCheck issues in: $script"
      sed -n '1,200p' "$sc_tmp"
    fi
  else
    # still show warnings if verbose
    if [ "${VERBOSE:-0}" = "1" ]; then
      if [ -s "$sc_tmp" ]; then
        echo "ShellCheck messages for: $script"
        sed -n '1,200p' "$sc_tmp"
      fi
    fi
    rm -f "$sc_tmp"
  fi
done

if [ $sc_failures -ne 0 ]; then
  echo "ShellCheck found $sc_failures issue(s)."
  if [ "${VERBOSE:-0}" != "1" ]; then
    echo "Run with VERBOSE=1 to show all ShellCheck output, or set SHELLCHECK_STRICT=1 to fail on issues."
  fi
  if [ "${SHELLCHECK_STRICT:-0}" = "1" ]; then
    # print the issues before exiting
    for entry in "${SC_ISSUES[@]}"; do
      script=${entry%%:*}
      scfile=${entry#*:}
      echo "--- $script ---"
      sed -n '1,200p' "$scfile"
      rm -f "$scfile"
    done
    echo "SHELLCHECK_STRICT=1: failing due to ShellCheck issues."
    exit 3
  else
    # print a brief summary of the first few issues when not strict
    count=0
    for entry in "${SC_ISSUES[@]}"; do
      script=${entry%%:*}
      scfile=${entry#*:}
      # show one-line summary (first non-empty line) and issue count
      first_line=$(sed -n '1p' "$scfile" | tr -d '\n')
      issues_count=$(wc -l <"$scfile" | tr -d ' ')
      echo "${script}: ${issues_count} issue(s) - ${first_line}"
      rm -f "$scfile"
      count=$((count+1))
      if [ $count -ge 10 ]; then
        echo "...and more. Use VERBOSE=1 to see all messages."
        break
      fi
    done
    echo "Set SHELLCHECK_STRICT=1 to treat ShellCheck issues as failures."
  fi
fi

exit 0
