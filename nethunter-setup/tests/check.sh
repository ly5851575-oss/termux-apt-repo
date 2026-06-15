#!/usr/bin/env bash

set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for script in \
  "$ROOT/bootstrap.sh" \
  "$ROOT/install.sh" \
  "$ROOT/install-tools.sh" \
  "$ROOT/doctor.sh" \
  "$ROOT/lib/common.sh"; do
  bash -n "$script"
  printf 'OK: %s\n' "${script#$ROOT/}"
done

for list in "$ROOT"/packages/*.txt; do
  if grep -Ev '^[[:space:]]*(#.*|[a-z0-9][a-z0-9+.-]*|)[[:space:]]*$' "$list"; then
    printf 'Invalid package-list line in %s\n' "$list" >&2
    exit 1
  fi
  printf 'OK: %s\n' "${list#$ROOT/}"
done

duplicates="$(cat "$ROOT"/packages/*.txt | sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' | sort | uniq -d)"
if [[ -n "$duplicates" ]]; then
  printf 'Duplicate package entries:\n%s\n' "$duplicates" >&2
  exit 1
fi

printf 'OK: no duplicate package entries\n'
