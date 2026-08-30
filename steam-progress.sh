#!/bin/bash
# Steam bootstrap progress probe. Prints exactly one line:
#   off          Steam not running
#   down:<pct>   Steam running and its self-update download is in progress
#   done         Steam running but no download activity in the last 3 minutes
#                (bootstrap finished, or a rare >3min download stall)
# The 3-minute window keeps the widget from showing stale percentages from
# an older Steam session; the bootstrap download logs every second while
# active, so a quiet journal means the update is over.
if ! pgrep -f "$HOME/.local/share/Steam/steam.sh" >/dev/null 2>&1; then
  echo "off"
  exit 0
fi

pct=$(journalctl -t steam --since "-3 minutes" --output=cat --no-pager 2>/dev/null \
      | grep -o 'Set percent complete: [0-9]\+' | tail -1 | grep -o '[0-9]\+$')

if [ -z "$pct" ]; then
  echo "done"
else
  echo "down:$pct"
fi
