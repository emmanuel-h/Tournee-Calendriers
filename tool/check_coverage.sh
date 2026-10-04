#!/usr/bin/env bash
# Coverage gate (PLAN §11): 100 % line coverage on the gated paths of lib/.
#
# Usage, from the project root:
#   flutter test --coverage && tool/check_coverage.sh [path/to/lcov.info]
#
# Exit codes: 0 gate passed, 1 gate failed, 2 lcov file missing.

set -euo pipefail

# Gated paths (extended regular expressions on paths relative to the project
# root): pure layers and the adapters' translation code.
GATED_PATTERNS=(
  '^lib/domain/'
  '^lib/application/'
  '^lib/presentation/'
  '^lib/infrastructure/(.+/)?mappers/'
)

# Gated paths deliberately left out of the gate, one regular expression per
# line, each with a comment saying why. Only the main session adds entries,
# and only for SDK glue that no test can reach (PLAN §11).
EXCLUDED_PATTERNS=(
)

LCOV_FILE="${1:-coverage/lcov.info}"

if [[ ! -f "$LCOV_FILE" ]]; then
  echo "No coverage file at $LCOV_FILE. Run 'flutter test --coverage' first." >&2
  exit 2
fi

matches_any() {
  local path="$1"
  shift
  local pattern
  for pattern in "$@"; do
    [[ "$path" =~ $pattern ]] && return 0
  done
  return 1
}

is_gated() {
  matches_any "$1" "${GATED_PATTERNS[@]}" &&
    ! matches_any "$1" ${EXCLUDED_PATTERNS[@]+"${EXCLUDED_PATTERNS[@]}"}
}

# A file no test imports never appears in lcov.info, and neither does a file
# without executable lines (an abstract port, a library doc). To tell them
# apart, look for a function body (`=>`, or `)` / `get name` followed by `{`)
# once comments are removed. False positives only ask for one more test.
has_code() {
  perl -0777 -ne '
    s{/\*.*?\*/}{}gs;
    s{//[^\n]*}{}g;
    exit((/=>/ || /\)\s*(?:async\*?|sync\*)?\s*\{/ || /\bget\s+\w+\s*\{/) ? 0 : 1);
  ' "$1"
}

# One line per source file: "<path> <covered> <total> <uncovered line list>".
# lcov paths may be absolute; they are made relative to the project root.
summary="$(awk -v root="$PWD/" '
  function flush() {
    if (file != "") print file, hit, total, (missed == "" ? "-" : missed)
  }
  /^SF:/ {
    flush()
    file = substr($0, 4)
    if (index(file, root) == 1) file = substr(file, length(root) + 1)
    hit = 0; total = 0; missed = ""
  }
  /^DA:/ {
    split(substr($0, 4), field, ",")
    total++
    if (field[2] > 0) hit++
    else missed = missed (missed == "" ? "" : ",") field[1]
  }
  END { flush() }
' "$LCOV_FILE")"

failures=0
gated_files=0
gated_hit=0
gated_total=0

while read -r path hit total missed; do
  [[ -z "${path:-}" ]] && continue
  is_gated "$path" || continue
  gated_files=$((gated_files + 1))
  gated_hit=$((gated_hit + hit))
  gated_total=$((gated_total + total))
  if ((hit < total)); then
    echo "FAIL $path  $hit/$total lines, uncovered: $missed"
    failures=$((failures + 1))
  fi
done <<<"$summary"

# Plain list instead of an associative array: macOS still ships bash 3.
lcov_paths="$(cut -d' ' -f1 <<<"$summary")"

if [[ -d lib ]]; then
  while IFS= read -r path; do
    grep -Fqx -- "$path" <<<"$lcov_paths" && continue
    is_gated "$path" || continue
    if has_code "$path"; then
      echo "FAIL $path  has code but no test loads it"
      failures=$((failures + 1))
    fi
  done < <(find lib -name '*.dart' -type f | sort)
fi

if ((failures > 0)); then
  echo "Coverage gate failed: $failures gated file(s) below 100 % line coverage."
  exit 1
fi
echo "Coverage gate passed: $gated_files gated file(s), $gated_hit/$gated_total lines covered."
