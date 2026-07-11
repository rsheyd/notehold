#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly RETENTION_SCRIPT="$PROJECT_DIR/scripts/manage-retention.sh"
readonly BACKUP_SCRIPT="$PROJECT_DIR/scripts/backup-apple-notes.sh"

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/apple-notes-retention-test.XXXXXX")
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

create_pair() {
  age_days="$1"
  archive_date=$(/bin/date -v-"$age_days"d '+%Y-%m-%d')
  archive="$work_dir/apple-notes-$archive_date-$age_days.zip"
  /usr/bin/printf 'archive content for age %s\n' "$age_days" >"$archive"
  checksum=$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{ print $1 }')
  /usr/bin/printf '%s  %s\n' "$checksum" "$(/usr/bin/basename "$archive")" >"$archive.sha256"
  /usr/bin/touch -t "$(/bin/date -v-"$age_days"d '+%Y%m%d%H%M.%S')" "$archive" "$archive.sha256"
}

archive_for_age() {
  age_days="$1"
  archive_date=$(/bin/date -v-"$age_days"d '+%Y-%m-%d')
  /usr/bin/printf '%s/apple-notes-%s-%s.zip\n' "$work_dir" "$archive_date" "$age_days"
}

for age in 0 10 20 30 40 90 180 365 500; do
  create_pair "$age"
done

create_pair 600
/usr/bin/printf 'corrupted after checksum creation\n' >>"$(archive_for_age 600)"

missing_checksum="$work_dir/apple-notes-test-missing-checksum.zip"
/usr/bin/printf 'must be protected\n' >"$missing_checksum"

mismatched="$work_dir/apple-notes-test-mismatched.zip"
/usr/bin/printf 'must also be protected\n' >"$mismatched"
/usr/bin/printf '%064d  wrong-name.zip\n' 0 >"$mismatched.sha256"

before_count=$(/usr/bin/find "$work_dir" -maxdepth 1 -type f -name 'apple-notes-*.zip' | /usr/bin/wc -l | /usr/bin/tr -d ' ')
BACKUP_DIR="$work_dir" NOTIFY_RETENTION=false "$RETENTION_SCRIPT" --preview >"$work_dir/preview.log"
after_preview_count=$(/usr/bin/find "$work_dir" -maxdepth 1 -type f -name 'apple-notes-*.zip' | /usr/bin/wc -l | /usr/bin/tr -d ' ')

if [ "$before_count" != "$after_preview_count" ]; then
  echo "Preview deleted an archive." >&2
  exit 1
fi

BACKUP_DIR="$work_dir" NOTIFY_RETENTION=false "$RETENTION_SCRIPT" --apply >"$work_dir/apply.log"

for age in 0 10 20 30 90 180 365; do
  test -f "$(archive_for_age "$age")"
  test -f "$(archive_for_age "$age").sha256"
done

test ! -e "$(archive_for_age 40)"
test ! -e "$(archive_for_age 40).sha256"
test ! -e "$(archive_for_age 500)"
test ! -e "$(archive_for_age 500).sha256"
test -f "$(archive_for_age 600)"
test -f "$(archive_for_age 600).sha256"
test -f "$missing_checksum"
test -f "$mismatched"
test -f "$mismatched.sha256"

/usr/bin/grep -q 'Retention preview only: no files were deleted.' "$work_dir/preview.log"
/usr/bin/grep -q 'Retention complete: deleted 2 redundant archive pair(s).' "$work_dir/apply.log"
/usr/bin/grep -q 'matching checksum file is missing' "$work_dir/apply.log"
/usr/bin/grep -q 'checksum metadata is invalid or mismatched' "$work_dir/apply.log"
/usr/bin/grep -q 'checksum verification failed before deletion' "$work_dir/apply.log"

/bin/mkdir -p "$work_dir/test-home/Library/Logs"
wrapper_output=$(
  HOME="$work_dir/test-home" BACKUP_DIR="$work_dir" NOTIFY_RETENTION=false \
    "$BACKUP_SCRIPT" --retention-preview
)
/usr/bin/printf '%s\n' "$wrapper_output" | /usr/bin/grep -q 'Retention preview only: no files were deleted.'
/usr/bin/grep -q 'Retention preview only: no files were deleted.' "$work_dir/apple-notes-backup.log"

echo "Retention tests passed."
