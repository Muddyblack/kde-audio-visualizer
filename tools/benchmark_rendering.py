#!/usr/bin/env python3
"""Measure software CPU work with synthetic audio; this does not measure GPU power.

Save a pre-change copy of package/ first, then compare it with the working tree:
  python3 tools/benchmark_rendering.py --baseline /tmp/audio-power-before/package
  python3 tools/benchmark_rendering.py --style 15 --renderer waveform

The software scene graph intentionally omits the new GPU glow. This isolates
the CPU raster work removed by moving the blur out of Canvas; use the real
desktop to measure the resulting GPU/compositor cost and power consumption.
"""

import argparse
import json
import os
import re
import resource
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


def measure(package, args):
    ui = package.resolve() / "contents" / "ui"
    if not (ui / "WaveCanvas.qml").is_file():
        raise SystemExit(f"No WaveCanvas.qml in {ui}")
    with tempfile.TemporaryDirectory(prefix="audio-render-benchmark-") as directory:
        motion = (
            """
            visualFrameTime: root.ticks * 33
            bass: 0.5 + 0.3 * Math.sin(root.ticks * 0.1)
            mid: 0.6
            high: 0.4
            vizColorMode: "palette"
        """
            if args.style >= 6
            else ""
        )
        if args.style >= 6 and args.renderer == "waveform":
            motion += "\n            attack: root.ticks % 15 === 0\n"
        component = (
            "OrbitCanvas"
            if args.renderer == "orbit"
            else "Waveform"
            if args.renderer == "waveform"
            else "WaveCanvas"
        )
        if args.renderer == "orbit":
            motion = (
                'visualFrameTime: root.ticks * 33; high: 0.4; vizColorMode: "palette"'
            )
        dimensions = (args.size, args.size) if args.size else (320, 44)
        width, height = dimensions
        style = (
            f'orbitStyle: "{args.orbit_style}"'
            if args.renderer == "orbit"
            else f"visualizerType: {args.style}"
        )
        config = Path(directory) / "benchmark.qml"
        config.write_text(f"""import QtQuick
import {json.dumps(ui.as_uri())} as Shared
Window {{
    id: root
    visible: true
    width: {args.copies * (width + 10)}
    height: {height + 40}
    property int ticks: 0
    Repeater {{
        model: {args.copies}
        Shared.{component} {{
            x: index * {width + 10}; y: 20; width: {width}; height: {height}
            {style}
            visible: {str(args.state != "hidden").lower()}
            hasAudio: {str(args.state != "idle").lower()}
            glowWave: true
            {motion}
            bars: {{
                const values = [];
                for (let i = 0; i < 24; i++)
                    values.push(500 + 350 * Math.sin(i * 0.32 + root.ticks * 0.14));
                return values;
            }}
        }}
    }}
    Timer {{ interval: 33; running: true; repeat: true; onTriggered: root.ticks++ }}
    Timer {{
        interval: {round(args.seconds * 1000)}
        running: true
        onTriggered: {{ console.log("BENCH_TICKS", root.ticks); Qt.quit(); }}
    }}
}}
""")
        env = os.environ | {
            "QT_QPA_PLATFORM": "offscreen",
            "QT_QUICK_BACKEND": "software",
            "QT_QPA_PLATFORMTHEME": "generic",
            "QT_QUICK_CONTROLS_STYLE": "Basic",
            "QT_FORCE_STDERR_LOGGING": "1",
        }
        before = resource.getrusage(resource.RUSAGE_CHILDREN)
        start = time.monotonic()
        result = subprocess.run(
            ["qml", str(config)],
            check=False, env=env,
            capture_output=True,
            text=True,
            timeout=args.seconds + 15,
        )
        elapsed = time.monotonic() - start
        after = resource.getrusage(resource.RUSAGE_CHILDREN)
        output = result.stdout + result.stderr
        ticks = re.search(r"BENCH_TICKS (\d+)", output)
        if (
            result.returncode
            or not ticks
            or any(
                message in output
                for message in (
                    "ReferenceError:",
                    "TypeError:",
                    "Binding loop detected",
                    "Cannot assign",
                )
            )
        ):
            raise SystemExit(output or f"qml exited with {result.returncode}")
        # Report other QML warnings rather than allowing broken rendering to
        # look like a successful low-CPU result.
        for line in output.splitlines():
            if "BENCH_TICKS" not in line:
                print(line)
        cpu = after.ru_utime + after.ru_stime - before.ru_utime - before.ru_stime
        print(
            f"{package}: CPU {cpu:.3f}s / {elapsed:.3f}s wall "
            f"({cpu / elapsed * 100:.1f}% of one core), {ticks[1]} audio ticks"
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--copies", type=int, choices=range(1, 5), default=3)
    parser.add_argument("--style", type=int, choices=range(16), default=1)
    parser.add_argument(
        "--renderer",
        choices=("canvas", "waveform", "orbit"),
        default="canvas",
        help="waveform includes shared particles, peaks and ripples",
    )
    parser.add_argument("--size", type=int, help="square comparison size in pixels")
    parser.add_argument(
        "--orbit-style",
        choices=("bars", "wave", "dots", "ribbon", "sparks"),
        default="bars",
    )
    parser.add_argument("--seconds", type=float, default=5)
    parser.add_argument(
        "--state",
        choices=("live", "hidden", "idle"),
        default="live",
        help="keep synthetic frames arriving to check inactive renderer work",
    )
    args = parser.parse_args()
    if args.seconds <= 0 or not shutil.which("qml"):
        parser.error("qml must be on PATH and --seconds must be positive")
    print("Software Canvas CPU comparison; GPU glow/compositor/watts are not measured.")
    print(f"Renderer state: {args.state}")
    if args.baseline:
        measure(args.baseline, args)
    measure(Path(__file__).resolve().parents[1] / "package", args)


if __name__ == "__main__":
    main()
