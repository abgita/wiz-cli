---
name: wiz-lights
description: Controls Philips Wiz lights through this repo's ./wizctl CLI. Use when the user asks to list lights, turn lights on/off, set brightness, HSV color, white temperature, scenes, presets, status, discovery, or widget icons.
---

# Wiz Lights

Operate local Philips Wiz lights using the repository's public CLI: `./wizctl`.

## Ground Rules

- Run commands from the repository root unless already there.
- Use `./wizctl` for user-visible behavior; do not bypass it for normal light control.
- Light and preset names are exact CLI names. Query them before guessing if the user's wording is ambiguous.
- Quote names that contain spaces, for example `"Bathroom 1"` or `"Cool white"`.
- Only change lights/configuration when the user clearly asks.

## Inspect State

```bash
./wizctl list --json              # configured light names -> IPs
./wizctl list --details --json    # includes IP, MAC, widget icon metadata
./wizctl presets --json           # shipped presets merged with user presets
./wizctl status --all             # status for all configured lights
./wizctl status "Living"          # status for one light
./wizctl icons --json             # valid widget icon names
```

## Control Lights

```bash
./wizctl on "Living"
./wizctl off "Bedroom"
./wizctl dim "Desktop" 65
./wizctl hsv "Living" 210 70 80
./wizctl hsv-preview 210 70 80
./wizctl temp "Living" 2700 100
./wizctl scene "Living" 6 80
./wizctl scene "Living" 6 80 120
./wizctl preset "Living" "Cozy"
```

Behavior to remember:

- `dim` clamps brightness to 10-100.
- `hsv` accepts hue, saturation, value; hue wraps, saturation clamps to 0-100, and value maps to dimming clamped to 10-100.
- `temp` clamps Kelvin to 2200-6500 and dimming to 10-100. Dimming defaults to 100 if omitted.
- `scene` accepts scene id, optional dimming, optional speed. Dimming defaults to 100; speed clamps to 10-200 when provided.
- `preset` applies RGB, white-temperature, or scene presets from `./wizctl presets --json`. Scene presets preserve the bulb's current dimming/speed.

## Presets and Configuration

```bash
./wizctl save-preset "Living" "My Preset"
./wizctl discover --dry-run
./wizctl discover
./wizctl discover --interactive
./wizctl discover --subnet 192.168.0.0/24
./wizctl set-icon "Living" icon_08
./wizctl set-icon "Living" default
```

Safety notes:

- Prefer `discover --dry-run` for inspection.
- Use `discover`, `discover --interactive`, `save-preset`, or `set-icon` only when requested because they can update runtime files under `~/.wiz-cli/`.
- Do not install, remove, or reload the Plasma widget unless explicitly requested.

## Workflow

1. Parse the user's requested target light(s), action, brightness, color/temperature/scene, preset, or configuration change.
2. If needed, run `./wizctl list --json`, `./wizctl presets --json`, or `./wizctl icons --json` to resolve exact names.
3. If multiple names match or no name matches, ask for clarification and show the available options.
4. Execute the smallest appropriate `./wizctl` command.
5. Summarize briefly: command run, resolved light/preset/icon, and CLI result or error.
