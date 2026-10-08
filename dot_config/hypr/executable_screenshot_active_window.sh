#!/usr/bin/env bash

set -o pipefail

geometry=$(hyprctl -j activewindow | jq -er '
  select(.mapped == true and .size[0] > 0 and .size[1] > 0)
  | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
') || {
  notify-send "Screenshot" "Nessuna finestra attiva" -u critical
  exit 1
}

if grim -c -g "$geometry" - | wl-copy; then
  notify-send "Screenshot" "Finestra attiva copiata negli appunti, puntatore incluso" -i image-x-generic
else
  notify-send "Screenshot" "Cattura non riuscita" -u critical
  exit 1
fi
