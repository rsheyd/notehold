#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly NOTEHOLD="$PROJECT_DIR/notehold"

help_output=$("$NOTEHOLD" help)
/usr/bin/printf '%s\n' "$help_output" | /usr/bin/grep -Fq 'notehold install'
/usr/bin/printf '%s\n' "$help_output" | /usr/bin/grep -Fq 'notehold retention preview'
/usr/bin/printf '%s\n' "$help_output" | /usr/bin/grep -Fq 'notehold uninstall'

version_output=$("$NOTEHOLD" version)
/usr/bin/printf '%s\n' "$version_output" | /usr/bin/grep -Eq '^Notehold [0-9A-Za-z._-]+$'

if "$NOTEHOLD" unknown >/dev/null 2>&1; then
  echo "Unknown command unexpectedly succeeded." >&2
  exit 1
fi

if "$NOTEHOLD" retention unknown >/dev/null 2>&1; then
  echo "Unknown retention command unexpectedly succeeded." >&2
  exit 1
fi

echo "Entrypoint tests passed."
