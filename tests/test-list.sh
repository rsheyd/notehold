#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly LIST_SCRIPT="$PROJECT_DIR/scripts/list-backups.sh"

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/notehold-list-test.XXXXXX")
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

backup_dir="$work_dir/backups"
/bin/mkdir -p "$backup_dir"

empty_output=$(BACKUP_DIR="$backup_dir" "$LIST_SCRIPT")
/usr/bin/printf '%s\n' "$empty_output" | /usr/bin/grep -Fq 'No backups found.'

/usr/bin/printf 'older\n' >"$backup_dir/apple-notes-2026-01-01.zip"
/usr/bin/printf 'newer\n' >"$backup_dir/apple-notes-2026-02-01.zip"
/usr/bin/printf 'checksum\n' >"$backup_dir/apple-notes-2026-02-01.zip.sha256"
/usr/bin/touch -t 202601010101 "$backup_dir/apple-notes-2026-01-01.zip"
/usr/bin/touch -t 202602010101 "$backup_dir/apple-notes-2026-02-01.zip"

output=$(BACKUP_DIR="$backup_dir" "$LIST_SCRIPT")
first_archive=$(/usr/bin/printf '%s\n' "$output" | /usr/bin/grep '^apple-notes-' | /usr/bin/head -1)
/usr/bin/printf '%s\n' "$first_archive" | /usr/bin/grep -Fq 'apple-notes-2026-02-01.zip'
/usr/bin/printf '%s\n' "$first_archive" | /usr/bin/grep -Fq 'checksum present'
/usr/bin/printf '%s\n' "$output" | /usr/bin/grep 'apple-notes-2026-01-01.zip' | /usr/bin/grep -Fq 'checksum missing'

if BACKUP_DIR="$work_dir/missing" "$LIST_SCRIPT" >/dev/null 2>&1; then
  echo "Unavailable backup destination unexpectedly succeeded." >&2
  exit 1
fi

echo "List tests passed."
