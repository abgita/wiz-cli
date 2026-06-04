# Agent Notes

This repo provides `wizctl`, a Python-based CLI for local Philips Wiz lights, plus a KDE Plasma widget that calls the CLI. `README.md` is the user-facing guide; keep this file focused on implementation notes and agent workflow.

## Architecture

- `wizctl` is the public interface. Prefer adding or changing behavior there rather than calling helpers from UI code.
- `wiz_udp.py` is the low-level UDP helper for Wiz protocol calls on port `38899`.
- `discover_wiz_lights.py` backs `wizctl discover` and updates light IPs by stable MAC address.
- `presets.json` contains shipped defaults; user presets live in `~/.wiz-cli/presets.json`.
- `plasma-widget/com.github.abgita.wizlights/` contains the Plasma widget source.

## Runtime Data

Runtime state lives in `~/.wiz-cli/`:

- `config.json`: friendly light names mapped to current IP and MAC address.
- `presets.json`: user-saved presets and overrides.

Light entries should retain MAC addresses so discovery can repair changed IPs. Preset entries may be RGB (`r`, `g`, `b`, `dimming`), white temperature (`temp`, `dimming`), or scene-based (`sceneId`, optional speed/dimming depending on command behavior).

## Development Guidelines

- Use `./wizctl ...` for normal testing and user-visible behavior.
- Keep protocol details in Python, not QML.
- The Plasma widget should shell out to `wizctl` and consume CLI/JSON output.
- Keep widget behavior aligned with CLI behavior, especially HSV conversion, preset matching, and scene handling.
- Avoid new Python dependencies unless clearly justified; the project currently uses the standard library.
- Avoid long blocking operations in commands used by the widget.
- Do not add arbitrary command-execution paths.

## Plasma Widget Notes

- The widget expects `wizctl` in Plasma's `PATH`; installation normally symlinks it to `~/.local/bin/wizctl`.
- Prefer `PlasmaCore.ColorScope.*` for popup/panel theme consistency.
- Scene mode is selected through presets rather than a separate scene picker.
- Do not install, remove, or reload the widget from agent commands unless explicitly requested by the user.

## Useful Commands for Agents

```bash
./wizctl list --json
./wizctl status --all
./wizctl presets --json
./wizctl discover --dry-run
```

For manual widget development reloads, use `./reload-plasma-widget.sh` only when asked or when an interactive test requires it.
