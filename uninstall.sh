#!/usr/bin/env bash
set -euo pipefail

APPLET_ID="com.github.abgita.wizlights"
WIZCTL_LINK="$HOME/.local/bin/wizctl"
PURGE=false

if [[ "${1:-}" == "--purge" ]]; then
  PURGE=true
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--purge]" >&2
  exit 1
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
  KPACKAGETOOL=kpackagetool6
elif command -v kpackagetool5 >/dev/null 2>&1; then
  KPACKAGETOOL=kpackagetool5
else
  KPACKAGETOOL=""
fi

if [[ -n "$KPACKAGETOOL" ]]; then
  if "$KPACKAGETOOL" --type Plasma/Applet --list 2>/dev/null | grep -q "$APPLET_ID"; then
    "$KPACKAGETOOL" --type Plasma/Applet --remove "$APPLET_ID"
  fi
else
  echo "kpackagetool not found; skipping Plasma widget removal." >&2
fi

if [[ -L "$WIZCTL_LINK" ]]; then
  rm "$WIZCTL_LINK"
elif [[ -e "$WIZCTL_LINK" ]]; then
  echo "Not removing $WIZCTL_LINK because it is not a symlink." >&2
fi

if [[ "$PURGE" == true ]]; then
  rm -rf "$HOME/.wiz-cli"
fi

cat <<EOF

Uninstalled Wiz Lights.
EOF

if [[ "$PURGE" != true ]]; then
  cat <<EOF

Kept user data in ~/.wiz-cli.
Run with --purge to remove saved light config and presets.
EOF
fi
