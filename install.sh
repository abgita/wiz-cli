#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIZCTL_LINK="$HOME/.local/bin/wizctl"
APPLET_DIR="$ROOT/plasma-widget/com.github.abgita.wizlights"
APPLET_ID="com.github.abgita.wizlights"
OMARCHY_PLUGIN_DIR="$ROOT/omarchy-plugin"
OMARCHY_PLUGIN_LINK="$HOME/.config/omarchy/plugins/$APPLET_ID"
TARGET="${1:---plasma}"

if [[ "$TARGET" != "--plasma" && "$TARGET" != "--omarchy" ]]; then
  echo "Usage: $0 [--plasma|--omarchy]" >&2
  exit 1
fi

mkdir -p "$HOME/.local/bin" "$HOME/.wiz-cli"
ln -sf "$ROOT/wizctl" "$WIZCTL_LINK"

if [[ "$TARGET" == "--omarchy" ]]; then
  mkdir -p "$(dirname "$OMARCHY_PLUGIN_LINK")"
  # Plugin discovery expects a real directory and does not reliably traverse a
  # symlink at the plugin root. Keep the directory real and link its source files.
  if [[ -L "$OMARCHY_PLUGIN_LINK" ]]; then
    rm "$OMARCHY_PLUGIN_LINK"
  elif [[ -e "$OMARCHY_PLUGIN_LINK" && ! -d "$OMARCHY_PLUGIN_LINK" ]]; then
    echo "Error: $OMARCHY_PLUGIN_LINK exists and is not a directory." >&2
    exit 1
  fi
  mkdir -p "$OMARCHY_PLUGIN_LINK"
  ln -sfn "$OMARCHY_PLUGIN_DIR/manifest.json" "$OMARCHY_PLUGIN_LINK/manifest.json"
  ln -sfn "$OMARCHY_PLUGIN_DIR/Panel.qml" "$OMARCHY_PLUGIN_LINK/Panel.qml"

  if ! command -v omarchy-shell >/dev/null 2>&1 || ! command -v omarchy >/dev/null 2>&1; then
    echo "Error: omarchy-shell and omarchy are required to enable the plugin." >&2
    exit 1
  fi
  omarchy-shell shell rescanPlugins
  omarchy plugin enable "$APPLET_ID"

  cat <<EOF

Installed Wiz Lights for Omarchy.

The development plugin is linked from:
  $OMARCHY_PLUGIN_LINK

Configure lights if needed:
  wizctl discover --interactive
EOF
  exit 0
fi

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

Installed Wiz Lights for Plasma.

Next steps:
  1. Make sure ~/.local/bin is in the PATH used by Plasma.
  2. Configure lights if needed:
       wizctl discover --interactive
  3. Add the "Wiz Lights" widget from Plasma's widget picker.
EOF
