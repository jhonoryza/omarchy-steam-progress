# omarchy-steam-progress

A [Omarchy](https://omarchy.org/) shell plugin that shows a live progress bar
in the status bar while Steam downloads its bootstrap / self-update — plus a
one-time "Steam is ready" notification when it finishes.

No more staring at a blank screen wondering why Steam hasn't opened.

![Steam progress preview](preview.png)

## What it does

- **Bar widget** — a compact live readout in the bar (default: center section):
  - `Steam ▓▓▓░░ 57%` while Steam downloads its client self-update
  - `Europa ▓▓▓░░ 29%` while a game / content download runs (name of the
    largest active download; percentages are aggregated across concurrent
    downloads)
- **Auto-hide** — the widget only appears while something is actually
  downloading; it disappears when Steam is closed or idle
- **Ready notifications** — one-time pings (never spam) when the client
  update finishes, and when a tracked game download completes

## Requirements

- Omarchy (Hyprland + omarchy-shell) — uses the Omarchy shell plugin system
- `notify-send` (included with Omarchy's notification setup)
- Steam (native or flatpak-style `~/.local/share/Steam` layout)

## Install

```bash
omarchy plugin add https://github.com/jhonoryza/omarchy-steam-progress --enable
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
reports a single JSON state:

| State | Meaning | Widget |
|-------|---------|--------|
| `off` | Steam not running | hidden |
| `boot` | client self-update in progress (a `Set percent complete: N` line appeared in `journalctl -t steam` within the last 3 minutes) | `Steam <bar> N%` |
| `game` | game/content download in progress (an `appmanifest_*.acf` has StateFlags bit 1024 with `BytesToDownload > 0`; percentage = max of `BytesDownloaded` and the live allocated size of `steamapps/downloading/<appid>`, clamped to `BytesToDownload`, aggregated across concurrent downloads) | `<game name> <bar> N%` |
| `idle` | Steam running, nothing downloading | hidden |

Notifications fire on transitions: `boot → not boot` announces the client is
ready (once per Steam session); `game → not game` announces the game is ready,
but only if the last seen progress was ≥95% — below that the transition is
far more likely a paused or stalled download, so the widget stays quiet.

### Known limitations

- If a client download stalls completely for more than 3 minutes (e.g. the
  network drops mid-update), the plugin may treat it as "finished" and fire
  the client-ready notification early. Steam usually retries on its own, and
  the progress bar reappears as soon as logging resumes.
- Game progress blends two sources: the `appmanifest_*.acf` byte counts
  (Steam flushes them lazily, so they can lag minutes behind) and the
  allocated size of `steamapps/downloading/<appid>` (live, but includes a
  small per-file block-rounding overhead). The bar may therefore differ from
  Steam's own download page by a point or two either way.
- A game paused right at ≥95% could produce a premature "ready" notification.
  Rare, but possible.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Omarchy plugin manifest (`bar-widget` kind) |
| `Widget.qml` | The bar widget UI (Quickshell/QML, uses shell theme tokens) |
| `steam-progress.sh` | The state probe (`off` / `down:<pct>` / `done`) |

## License

MIT — see [LICENSE](LICENSE).
