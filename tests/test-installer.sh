#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly INSTALLER="$PROJECT_DIR/scripts/install-launchagent.sh"

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/apple-notes-installer-test.XXXXXX")
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

missing_destination="$work_dir/does-not-exist"
if HOME="$work_dir/home" BACKUP_DIR="$missing_destination" "$INSTALLER" \
  >"$work_dir/output.log" 2>&1; then
  echo "Installer accepted a missing explicit backup destination." >&2
  exit 1
fi

/usr/bin/grep -Fq "Backup destination was not found: $missing_destination" "$work_dir/output.log"
/usr/bin/grep -Fq "Choose an existing folder or create this folder, then run the installer again." "$work_dir/output.log"
test ! -e "$missing_destination"

echo "Installer tests passed."
