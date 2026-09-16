#!/usr/bin/env bash
# Waybar custom module: one JSON line per MPRIS change (needs playerctl).
#
#   "custom/audio": {
#     "exec": "/path/to/hyprland/run.sh --waybar",
#     "return-type": "json",
#     "on-click": "playerctl play-pause"
#   }
#
# Fields: text ("Title · Artist"), tooltip (title, artist, album, player),
# class (playing | paused | stopped) and alt (the player name). Animation-free.
set -u

if ! command -v playerctl >/dev/null 2>&1; then
  printf '{"text":"","tooltip":"playerctl is not installed","class":"stopped","alt":""}\n'
  exit 0
fi

json() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\t'/ }
  value=${value//$'\r'/}
  printf '"%s"' "$value"
}

emit() {
  local status=$1 player=$2 artist=$3 title=$4 album=$5 class text tooltip
  case $status in
    Playing) class=playing ;;
    Paused) class=paused ;;
    *) class=stopped ;;
  esac
  if [[ -z $title ]]; then
    text=""
  elif [[ -n $artist ]]; then
    text="$title · $artist"
  else
    text=$title
  fi
  tooltip=$title
  [[ -n $artist ]] && tooltip+=$'\n'"$artist"
  [[ -n $album ]] && tooltip+=$'\n'"$album"
  [[ -n $player ]] && tooltip+=$'\n'"$player"
  printf '{"text":%s,"tooltip":%s,"class":"%s","alt":%s}\n' \
    "$(json "$text")" "$(json "$tooltip")" "$class" "$(json "$player")"
}

emit Stopped "" "" "" ""
# playerctl prints one line per metadata or status change; fields are separated
# by a unit separator so titles may contain tabs or pipes.
playerctl --follow metadata --format $'{{status}}\x1f{{playerName}}\x1f{{artist}}\x1f{{title}}\x1f{{album}}' 2>/dev/null |
  while IFS=$'\x1f' read -r status player artist title album; do
    emit "$status" "$player" "$artist" "$title" "$album"
  done
