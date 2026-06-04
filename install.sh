#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZCTL_LINK="$HOME/.local/bin/wizctl"
APPLET_DIR="$ROOT/plasma-widget/com.github.abgita.wizlights"
APPLET_ID="com.github.abgita.wizlights"

mkdir -p "$HOME/.local/bin" "$HOME/.wiz-cli"
ln -sf "$ROOT/wizctl" "$WIZCTL_LINK"

if command -v kpackagetool6 >/dev/null 2>&1; then
  KPACKAGETOOL=kpackagetool6
elif command -v kpackagetool5 >/dev/null 2>&1; then
  KPACKAGETOOL=kpackagetool5
else
  echo "Error: kpackagetool6 or kpackagetool5 is required to install the Plasma widget." >&2
  exit 1
fi

if "$KPACKAGETOOL" --type Plasma/Applet --list 2>/dev/null | grep -q "$APPLET_ID"; then
  "$KPACKAGETOOL" --type Plasma/Applet --upgrade "$APPLET_DIR"
else
  "$KPACKAGETOOL" --type Plasma/Applet --install "$APPLET_DIR"
fi

cat <<EOF

Installed Wiz Lights.

Next steps:
  1. Make sure ~/.local/bin is in the PATH used by Plasma.
  2. Configure lights if needed:
       wizctl discover --interactive
  3. Add the "Wiz Lights" widget from Plasma's widget picker.
EOF
