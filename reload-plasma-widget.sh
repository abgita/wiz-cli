#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIDGET_DIR="$ROOT/plasma-widget/com.github.abgita.wizlights"
LOG_FILE="${PLASMASHELL_RESTART_LOG:-/tmp/plasmashell-restart.log}"

if command -v kpackagetool5 >/dev/null 2>&1; then
  KPACKAGE=kpackagetool5
elif command -v kpackagetool6 >/dev/null 2>&1; then
  KPACKAGE=kpackagetool6
else
  echo "Error: kpackagetool5/kpackagetool6 not found" >&2
  exit 1
fi

echo "Upgrading Wiz Lights widget with $KPACKAGE..."
"$KPACKAGE" --type Plasma/Applet --upgrade "$WIDGET_DIR"

echo "Restarting plasmashell..."
if command -v kquitapp5 >/dev/null 2>&1; then
  kquitapp5 plasmashell || true
elif command -v kquitapp6 >/dev/null 2>&1; then
  kquitapp6 plasmashell || true
else
  pkill plasmashell || true
fi

sleep 2
nohup plasmashell >"$LOG_FILE" 2>&1 &
disown
sleep 3

if pgrep -x plasmashell >/dev/null; then
  echo "plasmashell restarted: $(pgrep -a plasmashell | head -1)"
  echo "Log: $LOG_FILE"
else
  echo "Error: plasmashell did not start. Last log lines:" >&2
  tail -80 "$LOG_FILE" >&2 || true
  exit 1
fi
