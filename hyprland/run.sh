#!/usr/bin/env bash
# Keep detached audio jobs tied to this preview, including terminal Ctrl+C.
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../shell.qml"
export QT_QPA_PLATFORMTHEME=generic
export QT_QUICK_CONTROLS_STYLE=Basic

# Waybar custom module: JSON lines on every player change.
if [[ ${1-} == --waybar ]]; then
  exec bash "$SCRIPT_DIR/waybar.sh"
fi

# IPC commands address an existing instance and must not own its lifetime.
if (($#)); then
  exec qs -p "$CONFIG" "$@"
fi

RUN="${XDG_RUNTIME_DIR:-/tmp}/audio-wave-quickshell"
mkdir -p "$RUN"
exec 8>"$RUN/launcher.lock"
if ! flock -n 8; then
  printf '%s\n' 'An instance of this configuration is already running.'
  exit 0
fi

# Quickshell can exit on SIGINT without running Component.onDestruction. Its
# detached QML commands inherit this token, including a pending feeder restart.
# A second launcher or a directly started shell has a different token.
OWNER="$BASHPID:$RANDOM:$EPOCHREALTIME"
shell_pid=""

cleanup() {
  trap '' INT TERM
  trap - EXIT
  local attempt environment pid
  local -a owned
  local -A signaled=()
  # grep -l names the readable environments (this user's processes) holding the
  # token and never prints their contents. It takes milliseconds; Bash's read
  # builtin took seconds per pass on large environments while Ctrl+C was ignored.
  # Recheck after signalling: a detached restart may just have forked its feeder.
  for ((attempt = 0; attempt < 50; attempt++)); do
    mapfile -t owned < <(grep -lsxzF -- "AUDIO_WAVE_OWNER=$OWNER" /proc/[0-9]*/environ)
    ((${#owned[@]})) || break
    for environment in "${owned[@]}"; do
      pid="${environment#/proc/}"
      pid="${pid%/environ}"
      if ((attempt == 49)); then
        kill -KILL "$pid" 2>/dev/null || :
      elif [[ ! -v "signaled[$pid]" ]]; then
        kill -TERM "$pid" 2>/dev/null || :
        signaled[$pid]=1
      fi
    done
    sleep 0.02
  done
  [[ -z "$shell_pid" ]] || wait "$shell_pid" 2>/dev/null || :
}
trap cleanup EXIT
# Ctrl+C is the documented way to stop a preview, not a failed make target.
trap 'exit 0' INT
trap 'exit 143' TERM

# Close our launcher lock in descendants; cleanup holds it until they stop.
# Only the shell and its descendants carry the token, not cleanup's own grep.
AUDIO_WAVE_OWNER="$OWNER" qs -n -p "$CONFIG" 8>&- &
shell_pid=$!
wait "$shell_pid"
