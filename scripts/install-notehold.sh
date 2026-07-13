#!/bin/bash

set -eu

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
readonly SOURCE_DIR="$(dirname "$SCRIPT_DIR")"
readonly VERSION_FILE="$SOURCE_DIR/VERSION"
readonly INSTALL_ROOT="${NOTEHOLD_INSTALL_ROOT:-$HOME/Library/Application Support/Notehold}"
readonly VERSIONS_DIR="$INSTALL_ROOT/versions"
readonly CURRENT_LINK="$INSTALL_ROOT/current"
readonly BIN_DIR="${NOTEHOLD_BIN_DIR:-$HOME/.local/bin}"
readonly COMMAND_LINK="$BIN_DIR/notehold"
readonly MARKER_FILE="$INSTALL_ROOT/.notehold-install"
readonly PAYLOAD_FILES=(
  VERSION
  notehold
  io.github.rsheyd.notehold.plist
  scripts/install-notehold.sh
  scripts/install-launchagent.sh
  scripts/manage-retention.sh
  scripts/notehold-backup.sh
  scripts/show-status.sh
  scripts/uninstall-notehold.sh
)

if [ -L "$INSTALL_ROOT" ]; then
  echo "Cannot install because the program directory is a symbolic link: $INSTALL_ROOT" >&2
  exit 1
fi
if [ -e "$INSTALL_ROOT" ] && [ ! -f "$MARKER_FILE" ]; then
  echo "Cannot install into an unrecognized existing directory: $INSTALL_ROOT" >&2
  exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
  echo "Notehold cannot determine its version: $VERSION_FILE is missing." >&2
  exit 1
fi

version=$(/usr/bin/awk 'NR == 1 { print; exit }' "$VERSION_FILE")
case "$version" in
  ''|*[!0-9A-Za-z._-]*)
    echo "Notehold has an invalid version: $version" >&2
    exit 1
    ;;
esac

readonly RELEASE_DIR="$VERSIONS_DIR/$version"

if [ -L "$VERSIONS_DIR" ] || [ -L "$RELEASE_DIR" ]; then
  echo "Cannot install through a symbolic-link versions path under $INSTALL_ROOT" >&2
  exit 1
fi

for relative_path in "${PAYLOAD_FILES[@]}"; do
  required_path="$SOURCE_DIR/$relative_path"
  if [ ! -f "$required_path" ]; then
    echo "Notehold installation file is missing: $required_path" >&2
    exit 1
  fi
done

if [ -e "$CURRENT_LINK" ] && [ ! -L "$CURRENT_LINK" ]; then
  echo "Cannot install because this path exists and is not a Notehold version link: $CURRENT_LINK" >&2
  exit 1
fi

if [ -e "$COMMAND_LINK" ] || [ -L "$COMMAND_LINK" ]; then
  if [ ! -L "$COMMAND_LINK" ]; then
    echo "Cannot install because another command already exists at $COMMAND_LINK" >&2
    exit 1
  fi
  existing_command_target=$(/usr/bin/readlink "$COMMAND_LINK")
  if [ "$existing_command_target" != "$CURRENT_LINK/notehold" ]; then
    echo "Cannot install because $COMMAND_LINK points somewhere other than this Notehold installation." >&2
    exit 1
  fi
fi

/bin/mkdir -p "$VERSIONS_DIR" "$BIN_DIR"
/usr/bin/touch "$MARKER_FILE"

staging_dir=$(/usr/bin/mktemp -d "$INSTALL_ROOT/.install-$version.XXXXXX")
temporary_current="$INSTALL_ROOT/.current.$$"
temporary_command="$BIN_DIR/.notehold.$$"
cleanup() {
  if [ -n "$staging_dir" ]; then
    /bin/rm -rf "$staging_dir"
  fi
  /bin/rm -f "$temporary_current" "$temporary_command"
}
trap cleanup EXIT HUP INT TERM

for relative_path in "${PAYLOAD_FILES[@]}"; do
  destination_path="$staging_dir/$relative_path"
  /bin/mkdir -p "$(/usr/bin/dirname "$destination_path")"
  /bin/cp "$SOURCE_DIR/$relative_path" "$destination_path"
done
/bin/chmod 755 "$staging_dir/notehold" "$staging_dir/scripts/"*.sh

if [ -d "$RELEASE_DIR" ]; then
  if ! /usr/bin/diff -qr "$staging_dir" "$RELEASE_DIR" >/dev/null; then
    echo "Notehold $version is already installed with different files." >&2
    echo "Refusing to replace a released version in place; install a newer version instead." >&2
    exit 1
  fi
else
  /bin/mv "$staging_dir" "$RELEASE_DIR"
  staging_dir=""
fi

/bin/ln -s "versions/$version" "$temporary_current"
/bin/mv -fh "$temporary_current" "$CURRENT_LINK"
/bin/ln -s "$CURRENT_LINK/notehold" "$temporary_command"
/bin/mv -fh "$temporary_command" "$COMMAND_LINK"

"$CURRENT_LINK/scripts/install-launchagent.sh"

echo "  Version: $version"
echo "  Command: $COMMAND_LINK"
echo "  Program files: $RELEASE_DIR"
case ":${PATH:-}:" in
  *":$BIN_DIR:"*) ;;
  *)
    echo
    echo "Warning: $BIN_DIR is not currently on PATH."
    echo "Add it to PATH before running notehold from another directory."
    ;;
esac
