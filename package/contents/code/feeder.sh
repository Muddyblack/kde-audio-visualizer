#!/usr/bin/env bash
# Runs cava in the background and mirrors its latest frame into $RUN/bars,
# which the QML side polls.
#
# cava is built with a fixed set of input backends and distros do not agree on
# which ones: a `method` that was not compiled in, or a sound server that is not
# running, makes cava either exit immediately or sit there emitting nothing. So
# instead of hardcoding pipewire we probe candidates until one actually produces
# a frame, and record the outcome in $RUN/status so the widget can say what went
# wrong instead of drawing a flat line forever.
set -u

BARS="${1:-24}"
FRAMERATE="${2:-60}"
SENSITIVITY="${3:-100}"
NOISE_REDUCTION="${4:-0.77}"
INPUT_METHOD="${5:-auto}"

RUN="${XDG_RUNTIME_DIR:-/tmp}/audio-wave-widget"
mkdir -p "$RUN"

CONF="$RUN/cava.conf"
STATUS="$RUN/status"
LOG="$RUN/cava.log"
MARKER="$RUN/.first-frame"
REMEMBERED="$RUN/input-method"

# How long a backend gets to produce its first frame before we call it dead.
# cava emits a frame every 1/framerate second even in silence, so no output
# after a few seconds means the backend never came up.
PROBE_TIMEOUT=5

# Backends tried, in order, when the method is left on "auto". alsa comes last
# because its default source (hw:Loopback,1) only exists if snd-aloop is loaded.
AUTO_METHODS="pipewire pulse alsa"

write_status() {
  printf '%s\n' "$*" >"$STATUS.tmp" && mv -f "$STATUS.tmp" "$STATUS"
}

exec 9>"$RUN/lock"
if ! flock -n 9; then
  exit 0
fi

# Ensure clean termination of the background cava process. The pkill pattern is
# pinned to our own config path so a cava the user started themselves survives.
cleanup() {
  pkill -P $$ >/dev/null 2>&1
  pkill -f "cava -p $CONF" >/dev/null 2>&1
  return 0
}
trap cleanup EXIT

# Generate initial zero-filled string for the requested number of bars
zeros=$(printf '0;%.0s' $(seq 1 "$BARS"))
printf '%s' "$zeros" >"$RUN/bars"

# Reported alongside "no-cava" so the widget can name the actual install
# command. Binary presence beats the /etc/os-release ID: derivatives keep their
# parent's package manager but change the ID, and there are far more
# derivatives than package managers.
detect_pkg_manager() {
  local mgr
  for mgr in apt-get dnf pacman zypper apk xbps-install emerge nix-env; do
    if command -v "$mgr" >/dev/null 2>&1; then
      printf '%s' "$mgr"
      return
    fi
  done
  printf 'unknown'
}

if ! command -v cava >/dev/null 2>&1; then
  write_status "error no-cava $(detect_pkg_manager)"
  exit 0
fi

: >"$LOG"

write_conf() {
  local method="$1"
  local source_line=""
  # alsa/sndio want a device name, not "auto" — leave cava on its own default.
  case "$method" in
  pipewire | pulse) source_line="source = auto" ;;
  esac

  cat <<EOF >"$CONF"
[general]
bars = $BARS
framerate = $FRAMERATE
autosens = 1
sensitivity = $SENSITIVITY

[input]
method = $method
$source_line

[output]
method = raw
channels = mono
mono_option = average
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10

[smoothing]
noise_reduction = $NOISE_REDUCTION
EOF
}

# Runs cava with one input method. Returns 0 if it produced at least one frame
# (i.e. the backend works and cava has since exited), 1 if the method is a dud.
run_method() {
  local method="$1"
  write_conf "$method"
  rm -f "$MARKER"

  cava -p "$CONF" 2>>"$LOG" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" >"$RUN/bars.tmp" && mv -f "$RUN/bars.tmp" "$RUN/bars"
    if [ ! -e "$MARKER" ]; then
      : >"$MARKER"
      printf '%s\n' "$method" >"$REMEMBERED"
      write_status "ok $method"
    fi
  done &
  local pipeline=$!

  # Watchdog: a backend that hangs without erroring out would otherwise block
  # the probe forever.
  (
    sleep "$PROBE_TIMEOUT"
    [ -e "$MARKER" ] && exit 0
    pkill -f "cava -p $CONF" >/dev/null 2>&1
    pkill -P "$pipeline" >/dev/null 2>&1
    kill "$pipeline" >/dev/null 2>&1
    return 0
  ) &
  local watchdog=$!

  wait "$pipeline" >/dev/null 2>&1
  kill "$watchdog" >/dev/null 2>&1
  wait "$watchdog" >/dev/null 2>&1

  [ -e "$MARKER" ]
}

methods=""
case "$INPUT_METHOD" in
auto | "")
  # Whatever worked last time goes first, so a restart does not re-probe.
  remembered=""
  if [ -r "$REMEMBERED" ]; then
    remembered="$(head -n1 "$REMEMBERED")"
  fi
  methods="$remembered"
  for m in $AUTO_METHODS; do
    [ "$m" = "$remembered" ] || methods="${methods:+$methods }$m"
  done
  ;;
*)
  methods="$INPUT_METHOD"
  ;;
esac

tried=""
for m in $methods; do
  write_status "probing $m"
  if run_method "$m"; then
    # The backend worked and cava has now exited (sound server restart, device
    # switch, ...). Report it and let the widget's heartbeat respawn us.
    write_status "error cava-exited $m"
    exit 0
  fi
  tried="${tried:+$tried,}$m"
done

write_status "error no-backend ${tried:-none}"
exit 0
