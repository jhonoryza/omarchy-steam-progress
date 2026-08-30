# omarchy-steam-progress

A [Omarchy](https://omarchy.org/) shell plugin that shows a live progress bar
in the status bar while Steam downloads its bootstrap / self-update — plus a
one-time "Steam is ready" notification when it finishes.

No more staring at a blank screen wondering why Steam hasn't opened.

<!-- Add a screenshot here: grim -g "$(hyprctl -j activewindow | jq -r .at)" ... -->

## What it does

- **Bar widget** — a compact `Steam ▓▓▓░░ 42%` readout in the bar (default:
  center section) while Steam is downloading its client update
- **Auto-hide** — the widget only appears while a download is actually in
  progress; it disappears when Steam is closed or the update finishes
- **Ready notification** — sends a single desktop notification the moment the
  bootstrap download completes (never more than once per Steam session)

## Requirements

- Omarchy (Hyprland + omarchy-shell) — uses the Omarchy shell plugin system
- `notify-send` (included with Omarchy's notification setup)
- Steam (native or flatpak-style `~/.local/share/Steam` layout)

## Install

```bash
omarchy plugin add https://github.com/<your-user>/omarchy-steam-progress.git --enable
```

`--enable` places the widget in its default bar section (center). To move it:

```bash
omarchy bar move vm.steam-progress --section right   # left | center | right
```

## Uninstall

```bash
omarchy plugin remove vm.steam-progress
```

## How it works

Every 2 seconds the widget runs a small probe (`steam-progress.sh`) that
checks:

1. Is `~/.local/share/Steam/steam.sh` running?
2. If yes, did Steam log a `Set percent complete: N` line in the last
   3 minutes? (via `journalctl -t steam`)

| Probe result | Meaning | Widget shows |
|--------------|---------|--------------|
| Steam not running | nothing to track | hidden |
| percent line found | download in progress | `Steam <bar> N%` |
| Steam running, no recent line | bootstrap finished | hidden + one-time notification |

The 3-minute window keeps stale percentages from older Steam sessions from
showing up, since Steam logs progress roughly every second while downloading.

### Known limitation

If a download stalls completely for more than 3 minutes (e.g. the network
drops mid-update), the plugin may treat it as "finished" and fire the
notification early. Steam usually retries on its own, and the progress bar
reappears as soon as logging resumes.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Omarchy plugin manifest (`bar-widget` kind) |
| `Widget.qml` | The bar widget UI (Quickshell/QML, uses shell theme tokens) |
| `steam-progress.sh` | The state probe (`off` / `down:<pct>` / `done`) |

## License

MIT — see [LICENSE](LICENSE).
