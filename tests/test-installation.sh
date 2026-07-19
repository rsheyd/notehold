#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly SOURCE_VERSION=$(/usr/bin/awk 'NR == 1 { print; exit }' "$PROJECT_DIR/VERSION")

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/notehold-installation-test.XXXXXX")
work_dir="$(cd "$work_dir" && pwd -P)"
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

test_home="$work_dir/home"
install_root="$work_dir/Notehold"
bin_dir="$test_home/.local/bin"
backup_dir="$work_dir/backups"
plist="$test_home/Library/LaunchAgents/io.github.rsheyd.notehold.plist"
zprofile="$test_home/.zprofile"
/bin/mkdir -p "$test_home" "$backup_dir"
/usr/bin/printf 'export EDITOR=vim\n' >"$zprofile"
/usr/bin/printf 'archive must survive uninstall\n' >"$backup_dir/apple-notes-keep.zip"

run_notehold() {
  HOME="$test_home" \
    NOTEHOLD_INSTALL_ROOT="$install_root" \
    NOTEHOLD_SKIP_LAUNCHCTL_FOR_TESTS=true \
    "$@"
}

install_output=$(
  BACKUP_DIR="$backup_dir" BACKUP_INTERVAL_DAYS=7 AUTO_CLEANUP=true \
    RESEND_EMAIL_TO="s.roman@gmail.com" \
    RESEND_EMAIL_FROM="Notehold <onboarding@resend.dev>" \
    run_notehold "$PROJECT_DIR/notehold" install
)

/usr/bin/printf '%s\n' "$install_output" | /usr/bin/grep -Fq "Version: $SOURCE_VERSION"
/usr/bin/printf '%s\n' "$install_output" | /usr/bin/grep -Fq "Shell PATH: added $bin_dir to $zprofile for future Terminal windows"
test -f "$install_root/.notehold-install"
test -x "$install_root/versions/$SOURCE_VERSION/notehold"
test -x "$install_root/versions/$SOURCE_VERSION/scripts/notehold-backup.sh"
test "$(/usr/bin/readlink "$install_root/current")" = "versions/$SOURCE_VERSION"
test "$(/usr/bin/readlink "$bin_dir/notehold")" = "$install_root/current/notehold"
test "$(run_notehold "$bin_dir/notehold" version)" = "Notehold $SOURCE_VERSION"
test "$(/usr/bin/grep -Fxc 'export EDITOR=vim' "$zprofile")" = "1"
test "$(/usr/bin/grep -Fxc 'export PATH="$HOME/.local/bin:$PATH"' "$zprofile")" = "1"

program_path=$(/usr/bin/plutil -extract ProgramArguments.0 raw -o - "$plist")
test "$program_path" = "$install_root/current/scripts/notehold-backup.sh"
test "$(/usr/bin/plutil -extract EnvironmentVariables.BACKUP_DIR raw -o - "$plist")" = "$backup_dir"
test "$(/usr/bin/plutil -extract EnvironmentVariables.BACKUP_INTERVAL_DAYS raw -o - "$plist")" = "7"
test "$(/usr/bin/plutil -extract EnvironmentVariables.AUTO_CLEANUP raw -o - "$plist")" = "true"
test "$(/usr/bin/plutil -extract EnvironmentVariables.RESEND_EMAIL_TO raw -o - "$plist")" = "s.roman@gmail.com"
test "$(/usr/bin/plutil -extract EnvironmentVariables.RESEND_EMAIL_FROM raw -o - "$plist")" = "Notehold <onboarding@resend.dev>"

# Manual commands inherit the installed destination without repeating BACKUP_DIR.
NOTIFY_RETENTION=false run_notehold "$bin_dir/notehold" retention preview >/dev/null
test -f "$backup_dir/notehold.log"

# Installing the same immutable version again is safe and idempotent.
run_notehold "$bin_dir/notehold" install >/dev/null
test "$(/usr/bin/grep -Fxc 'export PATH="$HOME/.local/bin:$PATH"' "$zprofile")" = "1"

# Reusing a released version number for different files is refused.
conflicting_source="$work_dir/conflicting-source"
/bin/mkdir -p "$conflicting_source"
/bin/cp -R "$install_root/versions/$SOURCE_VERSION/." "$conflicting_source/"
/usr/bin/printf '\n# changed without a version bump\n' >>"$conflicting_source/scripts/show-status.sh"
if run_notehold "$conflicting_source/notehold" install >"$work_dir/conflict.log" 2>&1; then
  echo "Installer replaced an existing version with different files." >&2
  exit 1
fi
/usr/bin/grep -Fq 'Refusing to replace a released version in place' "$work_dir/conflict.log"

# A new version switches the current link while preserving installed settings.
upgrade_source="$work_dir/upgrade-source"
/bin/mkdir -p "$upgrade_source"
/bin/cp -R "$install_root/versions/$SOURCE_VERSION/." "$upgrade_source/"
upgrade_version="${SOURCE_VERSION}.1"
/usr/bin/printf '%s\n' "$upgrade_version" >"$upgrade_source/VERSION"
run_notehold "$upgrade_source/notehold" install >/dev/null
test "$(/usr/bin/grep -Fxc 'export PATH="$HOME/.local/bin:$PATH"' "$zprofile")" = "1"

test "$(/usr/bin/readlink "$install_root/current")" = "versions/$upgrade_version"
test -d "$install_root/versions/$SOURCE_VERSION"
test -d "$install_root/versions/$upgrade_version"
test "$(run_notehold "$bin_dir/notehold" version)" = "Notehold $upgrade_version"
test "$(/usr/bin/plutil -extract ProgramArguments.0 raw -o - "$plist")" = "$install_root/current/scripts/notehold-backup.sh"
test "$(/usr/bin/plutil -extract EnvironmentVariables.BACKUP_DIR raw -o - "$plist")" = "$backup_dir"
test "$(/usr/bin/plutil -extract EnvironmentVariables.BACKUP_INTERVAL_DAYS raw -o - "$plist")" = "7"
test "$(/usr/bin/plutil -extract EnvironmentVariables.AUTO_CLEANUP raw -o - "$plist")" = "true"
test "$(/usr/bin/plutil -extract EnvironmentVariables.RESEND_EMAIL_TO raw -o - "$plist")" = "s.roman@gmail.com"
test "$(/usr/bin/plutil -extract EnvironmentVariables.RESEND_EMAIL_FROM raw -o - "$plist")" = "Notehold <onboarding@resend.dev>"

uninstall_output=$(run_notehold "$bin_dir/notehold" uninstall)
/usr/bin/printf '%s\n' "$uninstall_output" | /usr/bin/grep -Fq 'Backup archives, checksums, destinations, and logs were not removed.'
test ! -e "$install_root"
test ! -e "$bin_dir/notehold"
test ! -e "$plist"
test -f "$backup_dir/apple-notes-keep.zip"

# Safety guards do not claim existing directories or command names.
/bin/mkdir -p "$install_root"
/usr/bin/printf 'unrelated data\n' >"$install_root/keep.txt"
if run_notehold "$PROJECT_DIR/notehold" install >/dev/null 2>&1; then
  echo "Installer claimed an unrecognized program directory." >&2
  exit 1
fi
test -f "$install_root/keep.txt"
/bin/rm -rf "$install_root"

/usr/bin/printf '#!/bin/bash\necho unrelated\n' >"$bin_dir/notehold"
/bin/chmod 755 "$bin_dir/notehold"
if run_notehold "$PROJECT_DIR/notehold" install >/dev/null 2>&1; then
  echo "Installer overwrote an unrelated notehold command." >&2
  exit 1
fi
test "$("$bin_dir/notehold")" = "unrelated"

echo "Installation tests passed."
