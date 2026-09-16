#!/usr/bin/env python3
"""Count Qt window submissions during steady synthetic audio playback.

Run with Qt's `qml` runner on PATH:
    python3 tools/benchmark_frames.py
    python3 tools/benchmark_frames.py --baseline /tmp/audio-power-before --no-glow

The source and baseline trees must contain package/. This excludes cava, MPRIS,
the GPU and the desktop compositor: submissions are not screen FPS or watts.
The offscreen software renderer works without a running desktop. Disable glow
to isolate scheduling from old versions' expensive software shadows.
"""

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def configuration(source):
    namespace = {"k": "http://www.kde.org/standards/kcfg/1.0"}
    document = ET.parse(source / "package/contents/config/main.xml")
    values = {}
    for entry in document.findall(".//k:entry", namespace):
        value = entry.findtext("k:default", namespaces=namespace)
        kind = entry.attrib["type"]
        if kind == "Bool":
            value = value == "true"
        elif kind == "Int":
            value = int(value)
        elif kind == "Double":
            value = float(value)
        values[entry.attrib["name"]] = value
    return values


def harness(source, windows, fps, seconds, style, glow):
    settings = configuration(source) | {"progressBarStyle": style, "glowWave": glow}
    view = """
        Shared.VisualizerView {
            anchors.fill: parent
            configuration: benchmark.settings
            visualizer: audio
            player: media
            isPlaying: true
            positionUnitsPerSecond: 1
            fallbackIcon: Component { Item {} }
        }
    """
    additional = "\n".join(
        """
        Window {
            width: 360
            height: 104
            visible: true
            color: "transparent"
            onFrameSwapped: if (benchmark.measuring) benchmark.frames[%d]++
            %s
        }
        """  # noqa: UP031
        % (index, view)
        for index in range(1, windows)
    )
    return """import QtQuick
import QtQuick.Window
import "package/contents/ui" as Shared

Window {
    id: benchmark
    width: 360
    height: 104
    visible: true
    color: "transparent"
    property var settings: (%s)
    property var frames: %s
    property bool measuring: false
    property real startedAt: 0
    property int audioFrames: 0
    onFrameSwapped: if (measuring) frames[0]++

    QtObject {
        id: audio
        property var bars: Array(24).fill(500)
        property int numBars: 24
        property real maxRange: 1000
        property real frameTimeMs: Date.now()
        property bool hasAudio: true
        property bool backendFailed: false
        property bool plasmoidVisible: true
        property string backendCode: ""
        property string backendMessage: ""
        property string backendAction: ""
        property string backendHint: ""
    }
    QtObject {
        id: media
        property string artist: "Synthetic audio"
        property string track: "Rendering benchmark"
        property string artUrl: ""
        property string desktopEntry: ""
        property real length: 180
        property real position: 60
        property bool canSeek: true
        property bool positionSupported: true
    }
    Timer {
        property int sequence: 0
        interval: %d
        repeat: true
        running: true
        onTriggered: {
            sequence++;
            audio.bars = Array.from({length: 24}, (_, index) =>
                Math.round(500 + 350 * Math.sin(sequence / 5 + index / 3)));
            audio.frameTimeMs = Date.now();
            if (benchmark.measuring) benchmark.audioFrames++;
        }
    }
    Timer {
        interval: 800
        running: true
        onTriggered: {
            benchmark.startedAt = Date.now();
            benchmark.measuring = true;
        }
    }
    Timer {
        interval: %d
        running: benchmark.measuring
        onTriggered: {
            benchmark.measuring = false;
            console.log("BENCHMARK_JSON " + JSON.stringify({
                seconds: (Date.now() - benchmark.startedAt) / 1000,
                audio_frames: benchmark.audioFrames,
                window_frames: benchmark.frames
            }));
            Qt.quit();
        }
    }
    %s
    %s
}
""" % (  # noqa: UP031
        json.dumps(settings),
        json.dumps([0] * windows),
        round(1000 / fps),
        round(seconds * 1000),
        view,
        additional,
    )


def measure(qml, source, windows, fps, seconds, style, glow):
    with tempfile.TemporaryDirectory(prefix="audio-frame-benchmark-") as directory:
        root = Path(directory)
        shutil.copytree(source / "package", root / "package")
        script = root / "benchmark.qml"
        script.write_text(harness(source, windows, fps, seconds, style, glow))
        env = os.environ | {
            "QT_QPA_PLATFORM": "offscreen",
            "QT_QPA_PLATFORMTHEME": "generic",
            "QT_QUICK_CONTROLS_STYLE": "Basic",
            "QT_QUICK_BACKEND": "software",
            "QT_FORCE_STDERR_LOGGING": "1",
            "QT_LOGGING_RULES": "qml.debug=true;qml.info=true",
            "XDG_RUNTIME_DIR": directory,
        }
        result = subprocess.run(
            [qml, str(script)],
            check=False, env=env,
            text=True,
            capture_output=True,
            timeout=seconds + 15,
        )
        output = result.stdout + result.stderr
        runtime_error = any(
            message in output
            for message in ("ReferenceError:", "TypeError:", "Binding loop detected")
        )
        if result.returncode == 0 and not runtime_error:
            for line in output.splitlines():
                if "BENCHMARK_JSON " in line:
                    return json.loads(line.split("BENCHMARK_JSON ", 1)[1])
        raise RuntimeError(f"qml exited {result.returncode}:\n{output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        default=REPO,
        help="tree containing package/ (default: this checkout)",
    )
    parser.add_argument(
        "--baseline",
        type=Path,
        help="also measure a saved tree under identical conditions",
    )
    parser.add_argument("--windows", type=int, nargs="+", default=[1, 3])
    parser.add_argument("--fps", type=int, default=30)
    parser.add_argument("--seconds", type=float, default=2)
    parser.add_argument("--style", type=int, choices=range(5), default=0)
    parser.add_argument(
        "--no-glow",
        dest="glow",
        action="store_false",
        help="isolate scheduling from old software shadows",
    )
    args = parser.parse_args()
    if args.fps < 1 or args.fps > 1000 or args.seconds <= 0 or min(args.windows) < 1:
        parser.error("fps must be 1–1000, duration and window counts must be positive")
    qml = shutil.which("qml")
    if not qml:
        parser.error("Qt's qml runner must be on PATH")
    sources = [("current", args.source)]
    if args.baseline:
        sources.insert(0, ("baseline", args.baseline))
    for label, source in sources:
        for windows in args.windows:
            result = measure(
                qml,
                source.resolve(),
                windows,
                args.fps,
                args.seconds,
                args.style,
                args.glow,
            )
            result |= {
                "source": label,
                "windows": windows,
                "progress_style": args.style,
                "glow": args.glow,
                "window_submissions_per_second": [
                    round(frames / result["seconds"], 1)
                    for frames in result["window_frames"]
                ],
                "audio_fps": round(result["audio_frames"] / result["seconds"], 1),
            }
            print(json.dumps(result), flush=True)


if __name__ == "__main__":
    main()
