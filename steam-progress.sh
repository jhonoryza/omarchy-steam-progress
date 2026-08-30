#!/bin/bash
# Steam progress probe for omarchy-steam-progress.
# Prints exactly one JSON line so the QML widget can JSON.parse it:
#   {"state":"off"}                     Steam not running
#   {"state":"boot","pct":N}            client self-update in progress
#   {"state":"game","pct":N,"name":"X"} content/game download in progress
#   {"state":"idle"}                    Steam running, nothing downloading
#
# Priority: boot > game > idle. A game download is detected from
# appmanifest_*.acf files whose StateFlags have bit 1024 (active
# download/validate) and non-zero BytesToDownload; percentages are aggregated
# across concurrent downloads, with the largest download lending its name.
if ! pgrep -f "$HOME/.local/share/Steam/steam.sh" >/dev/null 2>&1; then
  echo '{"state":"off"}'
  exit 0
fi

# 1) Client bootstrap / self-update (journal logs every second while active;
#    a quiet 3-minute window means the client update is over).
pct=$(journalctl -t steam --since "-3 minutes" --output=cat --no-pager 2>/dev/null \
      | grep -o 'Set percent complete: [0-9]\+' | tail -1 | grep -o '[0-9]\+$')
if [ -n "$pct" ]; then
  jq -n --argjson p "$pct" '{"state":"boot","pct":$p}'
  exit 0
fi

# 2) Game / content downloads.
sum_to=0
sum_dl=0
big_to=0
big_name=""
for f in "$HOME"/.local/share/Steam/steamapps/appmanifest_*.acf; do
  [[ -e "$f" ]] || continue
  flags=$(grep -m1 '"StateFlags"' "$f" | tr -dc '0-9')
  (( flags & 1024 )) || continue
  to=$(grep -m1 '"BytesToDownload"' "$f" | tr -dc '0-9'); to=${to:-0}
  dl=$(grep -m1 '"BytesDownloaded"' "$f" | tr -dc '0-9'); dl=${dl:-0}
  (( to > 0 )) || continue
  name=$(grep -m1 '"name"' "$f" | awk -F'"' '{print $4}')
  sum_to=$((sum_to + to))
  sum_dl=$((sum_dl + dl))
  if (( to > big_to )); then
    big_to=$to
    big_name=$name
  fi
done

if (( sum_to > 0 )); then
  pct=$((sum_dl * 100 / sum_to))
  jq -n --argjson p "$pct" --arg n "$big_name" '{"state":"game","pct":$p,"name":$n}'
  exit 0
fi

echo '{"state":"idle"}'
