#!/usr/bin/env python3
"""Run with Python 3 and Qt 6 qmltestrunner on PATH. No desktop/audio access needed."""

import base64
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
FEEDER = REPO / "package/contents/code/feeder.sh"
runner = shutil.which("qmltestrunner")
if not runner:
    raise SystemExit("Qt 6 qmltestrunner must be on PATH")

subprocess.run([sys.executable, str(REPO / "tools/sync_studio_assets.py")], check=True)
subprocess.run(
    [sys.executable, str(REPO / "tools/sync_studio_assets.py"), "--check"], check=True
)
subprocess.run([sys.executable, str(REPO / "tests/test_feeder.py")], check=True)
subprocess.run([sys.executable, str(REPO / "tests/test_waybar.py")], check=True)

# The widget loads the compiled packages. Verify every family and the common
# prelude with the same builder used by make, so a stale .qsb cannot pass.
qsb = shutil.which("qsb")
if qsb:
    subprocess.run(
        [
            sys.executable,
            str(REPO / "package/contents/shaders/build_shaders.py"),
            "--check",
        ],
        check=True,
    )
else:
    print("SKIP: qsb is not on PATH; compiled shader families not checked")


def start(env, bars, method):
    command = ["bash", str(FEEDER), str(bars), "60", "100", "0.77", method]
    return command, subprocess.Popen(command, env=env, start_new_session=True)


def stop(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    process.wait(timeout=3)


def wait_for(condition, message, process=None, timeout=5):
    deadline = time.monotonic() + timeout
    while not condition():
        if (process and process.poll() is not None) or time.monotonic() > deadline:
            raise AssertionError(message)
        time.sleep(0.02)


with tempfile.TemporaryDirectory(prefix="audio-visualizer-test-") as directory:
    runtime = Path(directory)
    run = runtime / "audio-wave-widget"
    binaries = runtime / "bin"
    binaries.mkdir()
    # Exercise the real feeder with changing frames, without capturing audio.
    cava = binaries / "cava"
    cava.write_text("""#!/usr/bin/env bash
[[ $(<"$2") == *'bar_delimiter = 59'* ]] || exit 1
# A backend that never delivers a frame, which keeps the feeder probing.
if [[ -e $0.silent ]]; then
    while :; do sleep 0.1; done
fi
while :; do
    for value in 100 900; do
        for ((i=0; i<15; i++)); do
            printf '%s;%s;%s;%s;\\n' "$value" "$value" "$value" "$value"
            sleep 0.017
        done
    done
done
""")
    cava.chmod(0o755)
    stale = runtime / "old-feeder"
    stale.mkdir()
    (stale / "frame.ini").write_text("t=1\nv=0,0,0,0,\n")
    env = os.environ | {
        "PATH": str(binaries) + os.pathsep + os.environ["PATH"],
        "XDG_RUNTIME_DIR": directory,
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QPA_PLATFORMTHEME": "generic",
        "QT_QUICK_BACKEND": "software",
        "QT_QUICK_CONTROLS_STYLE": "Basic",
        "QT_FORCE_STDERR_LOGGING": "1",
        "QML_DISABLE_DISK_CACHE": "1",
        "QML_XHR_ALLOW_FILE_READ": "1",
    }
    command, feeder = start(env, 4, "pipewire")
    try:
        status = run / "status"
        wait_for(
            lambda: status.exists() and status.read_text().strip() == "ok pipewire",
            "Feeder failed to start",
            feeder,
        )
        # An installed reader must still see the original four semicolon bars.
        bars = run / "bars"
        for _ in range(20):
            frame = bars.read_text()
            if frame:
                break
            time.sleep(0.01)
        assert len(frame.rstrip(";").split(";")) == 4 and "v=" not in frame, frame
        # Joining the shared lock must not replace the existing feeder.
        subprocess.run(command, env=env, timeout=3, check=True)
        assert feeder.poll() is None
        subprocess.run(
            [
                runner,
                "-input",
                str(REPO / "tests"),
                "-import",
                str(REPO / "tests/stubs"),
            ],
            env=env,
            timeout=60,
            check=True,
        )
        print("PASS: legacy transport, live INI frames, silence/wake, shared startup")
    finally:
        stop(feeder)

    # A restart while the feeder probes backends must replace it with one on
    # the new settings, not leave it probing the next backend with the old
    # ones. The command is the one the QML test captured from restart().
    exported = (runtime / "commands.ini").read_text().split("restart=", 1)[1].split()[0]
    restart = base64.b64decode(exported + "=" * (-len(exported) % 4)).decode()
    (binaries / "cava.silent").touch()
    conf = run / "cava.conf"
    _, probing = start(env, 6, "auto")
    restarted = None
    try:
        wait_for(
            lambda: "bars = 6" in conf.read_text(),
            "Probing feeder failed to start",
            probing,
        )
        restarted = subprocess.Popen(
            ["sh", "-c", restart], env=env, start_new_session=True
        )
        wait_for(
            lambda: probing.poll() is not None and "bars = 4" in conf.read_text(),
            "Restart kept the old feeder and settings",
        )
        print("PASS: restart during a backend probe applies the new settings")
    finally:
        stop(probing)
        if restarted:
            stop(restarted)
