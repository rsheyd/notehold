#!/bin/bash

set -eu

readonly LABEL="io.github.rsheyd.notehold"
readonly INSTALL_ROOT="${NOTEHOLD_INSTALL_ROOT:-$HOME/Library/Application Support/Notehold}"
readonly BIN_DIR="${NOTEHOLD_BIN_DIR:-$HOME/.local/bin}"
readonly COMMAND_LINK="$BIN_DIR/notehold"
readonly INSTALLED_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
readonly MARKER_FILE="$INSTALL_ROOT/.notehold-install"

case "$INSTALL_ROOT" in
  ''|'/'|"$HOME"|"$HOME/Library"|"$HOME/Library/Application Support")
    echo "Refusing to uninstall from an unsafe program path: $INSTALL_ROOT" >&2
    exit 1
    ;;
esac

if [ -L "$INSTALL_ROOT" ]; then
  echo "Refusing to uninstall from a symbolic-link program path: $INSTALL_ROOT" >&2
  exit 1
fi
if [ -e "$INSTALL_ROOT" ] && [ ! -f "$MARKER_FILE" ]; then
  echo "Refusing to uninstall from an unrecognized program directory: $INSTALL_ROOT" >&2
  exit 1
fi

if [ "${NOTEHOLD_SKIP_LAUNCHCTL_FOR_TESTS:-false}" != "true" ]; then
  /bin/launchctl bootout "gui/$(/usr/bin/id -u)/$LABEL" 2>/dev/null || true
  if /bin/launchctl print "gui/$(/usr/bin/id -u)/$LABEL" >/dev/null 2>&1; then
    echo "Notehold is still loaded, so no installed files were removed." >&2
    exit 1
  fi
fi

if [ -f "$INSTALLED_PLIST" ]; then
  installed_label=$(/usr/bin/plutil -extract Label raw -o - "$INSTALLED_PLIST" 2>/dev/null || true)
  if [ "$installed_label" = "$LABEL" ]; then
    /bin/rm -f "$INSTALLED_PLIST"
  else
    echo "Left an unrecognized LaunchAgent untouched: $INSTALLED_PLIST" >&2
  fi
fi

if [ -L "$COMMAND_LINK" ]; then
  command_target=$(/usr/bin/readlink "$COMMAND_LINK")
  if [ "$command_target" = "$INSTALL_ROOT/current/notehold" ]; then
    /bin/rm -f "$COMMAND_LINK"
  else
    echo "Left an unrelated command link untouched: $COMMAND_LINK" >&2
  fi
elif [ -e "$COMMAND_LINK" ]; then
  echo "Left an unrelated command untouched: $COMMAND_LINK" >&2
fi

if [ -e "$INSTALL_ROOT" ]; then
  /bin/rm -rf "$INSTALL_ROOT"
fi

echo "Notehold has been uninstalled."
echo "Backup archives, checksums, destinations, and logs were not removed."
