#!/usr/bin/env bash
# Diagnostics for "the bars don't move". Prints everything needed to tell apart
# a missing cava, a cava built without the right input backend, a sound server
# that is not reachable, and a widget/feeder problem.
#
#   bash ~/.local/share/plasma/plasmoids/org.muddyblack.plasmaAudioVisualizer/contents/code/doctor.sh
#
# Paste the output into a GitHub issue.
set -u

RUN="${XDG_RUNTIME_DIR:-/tmp}/audio-wave-widget"
PROBE_DIR="$(mktemp -d)"
trap 'rm -rf "$PROBE_DIR"' EXIT

section() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
# cava colours its messages and sets the terminal title; both would end up as
# garbage in a pasted issue report.
strip_esc() { sed -e 's/\x1b\][^\x07]*\x07//g' -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' -e 's/\r//g'; }

section "System"
if [ -r /etc/os-release ]; then
  . /etc/os-release
  echo "distro:  ${PRETTY_NAME:-unknown}"
fi
echo "kernel:  $(uname -r)"
echo "plasma:  $(plasmashell --version 2>/dev/null || echo 'not found')"
echo "session: ${XDG_SESSION_TYPE:-unset} / ${XDG_CURRENT_DESKTOP:-unset}"
echo "runtime: ${XDG_RUNTIME_DIR:-unset}"

section "cava"
if ! have cava; then
  echo "cava:    NOT INSTALLED  <- this is the problem"
  if have apt-get; then
    cmd="sudo apt install cava"
  elif have dnf; then
    cmd="sudo dnf install cava"
  elif have pacman; then
    cmd="sudo pacman -S cava"
  elif have zypper; then
    cmd="sudo zypper install cava"
  elif have apk; then
    cmd="sudo apk add cava"
  elif have xbps-install; then
    cmd="sudo xbps-install cava"
  elif have emerge; then
    cmd="sudo emerge media-sound/cava"
  elif have nix-env; then
    cmd="add pkgs.cava to your configuration"
  else
    cmd="install the 'cava' package"
  fi
  echo "         $cmd"
  echo "         The widget retries every 30s, so no Plasma restart is needed"
  echo "         unless your package manager only updates PATH for new sessions."
  exit 0
fi
echo "path:    $(command -v cava)"
echo "version: $(cava -v 2>&1 | strip_esc)"

# cava rejects an unknown input method by listing the ones it was built with,
# which is the only way to see the compiled-in backends.
printf '[input]\nmethod = __probe__\n' >"$PROBE_DIR/probe.conf"
built=$(cava -p "$PROBE_DIR/probe.conf" 2>&1 | strip_esc | sed -n "s/.*supported methods are: *//p" | tr -d "'")
echo "backends built in: ${built:-could not determine}"
if have ldd; then
  echo "linked audio libs: $(ldd "$(command -v cava)" 2>/dev/null |
    sed -n 's/^\s*\(lib\(pipewire\|pulse\|asound\|jack\|sndio\)[^ ]*\.so[^ ]*\).*/\1/p' |
    sort -u | tr '\n' ' ')"
fi

section "Sound servers"
if have pactl; then
  echo "pactl server: $(pactl info 2>&1 | sed -n 's/^Server Name: *//p' || true)"
  echo "default sink: $(pactl info 2>&1 | sed -n 's/^Default Sink: *//p' || true)"
else
  echo "pactl: not installed (cannot query PulseAudio/PipeWire-Pulse)"
fi
if have systemctl; then
  for unit in pipewire pipewire-pulse wireplumber pulseaudio; do
    printf '%-16s %s\n' "$unit:" "$(systemctl --user is-active "$unit" 2>/dev/null | head -1)"
  done
fi

section "Live capture probe (2s per backend)"
# Reproduces exactly what feeder.sh does, one backend at a time.
for method in pipewire pulse alsa; do
  conf="$PROBE_DIR/$method.conf"
  {
    echo "[general]"
    echo "bars = 8"
    echo "framerate = 30"
    echo "[input]"
    echo "method = $method"
    case "$method" in
    pipewire | pulse) echo "source = auto" ;;
    esac
    echo "[output]"
    echo "method = raw"
    echo "channels = mono"
    echo "raw_target = /dev/stdout"
    echo "data_format = ascii"
    echo "ascii_max_range = 1000"
  } >"$conf"

  out="$PROBE_DIR/$method.out"
  err="$PROBE_DIR/$method.err"
  cava -p "$conf" >"$out" 2>"$err" &
  pid=$!
  sleep 2
  kill "$pid" >/dev/null 2>&1
  wait "$pid" >/dev/null 2>&1

  frames=$(wc -l <"$out" | tr -d ' ')
  if [ "$frames" -gt 0 ]; then
    printf '%-9s OK    %s frames, last: %s\n' "$method" "$frames" "$(tail -n1 "$out" | cut -c1-40)"
  else
    printf '%-9s FAIL  %s\n' "$method" "$(tr '\n' ' ' <"$err" | sed 's/\x1b\[[0-9;]*m//g' | cut -c1-160)"
  fi
done
echo "(all zeros is normal if nothing is playing — play audio and re-run)"

section "Widget backend state"
if [ -d "$RUN" ]; then
  echo "runtime dir: $RUN"
  echo "status:      $(cat "$RUN/status" 2>/dev/null || echo '(none — feeder.sh never wrote one)')"
  echo "bars:        $(cut -c1-60 "$RUN/bars" 2>/dev/null || echo '(missing)')"
  echo "bars age:    $(($(date +%s) - $(stat -c %Y "$RUN/bars" 2>/dev/null || date +%s)))s"
  if [ -s "$RUN/cava.log" ]; then
    echo "cava.log:"
    sed 's/^/  /' "$RUN/cava.log"
  fi
else
  echo "$RUN does not exist — feeder.sh has not run."
  echo "The widget spawns it on start and every 30s, so if this stays empty the"
  echo "QML side never got that far. Look for errors (a missing"
  echo "org.kde.plasma.plasma5support module, for instance) with:"
  echo "  journalctl --user -b -t plasmashell --no-pager | tail -n 50"
fi
pgrep -af 'cava -p .*audio-wave-widget' || echo "no cava running for the widget"
