#!/usr/bin/env python3
"""Compare VisualizerView pixels against a saved view or Git revision.

Run before merging a visual-preserving refactor, for example:
  python3 tools/compare_view_snapshots.py --baseline-ref HEAD
  python3 tools/compare_view_snapshots.py --baseline-view /tmp/VisualizerView.qml

Both versions render in the same Qt process, with identical fonts, colors,
artwork, spectrum and a frozen playback clock. This avoids platform-dependent
PNG goldens and keeping a second implementation in the test tree. Git baselines
include their complete package; --baseline-view uses current dependencies and is
intended for refactors confined to the view. Images are saved for every case.

The default software backend is headless. Use --backend opengl --platform xcb
(or wayland) on a desktop to also exercise shader-based artwork and effects.
"""

import argparse
import io
import json
import os
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    baseline = parser.add_mutually_exclusive_group(required=True)
    baseline.add_argument(
        "--baseline-ref", help="Git revision containing the old package"
    )
    baseline.add_argument("--baseline-view", type=Path, help="Saved VisualizerView.qml")
    parser.add_argument("--backend", choices=("software", "opengl"), default="software")
    parser.add_argument("--platform", default="offscreen")
    parser.add_argument(
        "--case", help="Run one snapshot tag, for example classic-default"
    )
    parser.add_argument("--output", type=Path, help="Directory for before/after PNGs")
    args = parser.parse_args()
    runner = shutil.which("qmltestrunner")
    if not runner:
        parser.error("Qt 6 qmltestrunner must be on PATH")
    if args.baseline_view and not args.baseline_view.is_file():
        parser.error(f"Baseline view does not exist: {args.baseline_view}")
    output = (
        args.output.resolve()
        if args.output
        else Path(tempfile.mkdtemp(prefix="audio-view-snapshots-"))
    )
    output.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="audio-view-comparison-") as directory:
        runtime = Path(directory)
        current = runtime / "current" / "package"
        original = runtime / "baseline" / "package"
        shutil.copytree(REPO / "package", current)
        if args.baseline_ref:
            archive = subprocess.check_output(
                ["git", "archive", args.baseline_ref, "package"], cwd=REPO
            )
            with tarfile.open(fileobj=io.BytesIO(archive)) as package:
                package.extractall(original.parent, filter="data")
        else:
            shutil.copytree(current, original)
            shutil.copyfile(
                args.baseline_view, original / "contents/ui/VisualizerView.qml"
            )

        template = (REPO / "tests/snapshots/VisualizerComparison.qml.in").read_text()
        for key, value in {
            "BASELINE_UI": (original / "contents/ui").as_uri(),
            "CURRENT_UI": (current / "contents/ui").as_uri(),
            "CONFIGURATION_JS": (REPO / "hyprland/Configuration.js").as_uri(),
            "DEFAULTS_XML": (current / "contents/config/main.xml").as_uri(),
            "ARTWORK": (REPO / "package/icon.png").as_uri(),
            "OUTPUT": str(output),
            "BACKEND": args.backend,
        }.items():
            template = template.replace(f"@{key}@", json.dumps(value))
        test = runtime / "tst_visualcomparison.qml"
        test.write_text(template)
        env = os.environ | {
            "XDG_RUNTIME_DIR": directory
            if args.platform == "offscreen"
            else os.environ.get("XDG_RUNTIME_DIR", directory),
            "QT_QPA_PLATFORM": args.platform,
            "QT_QPA_PLATFORMTHEME": "generic",
            "QT_QUICK_CONTROLS_STYLE": "Basic",
            "QT_SCALE_FACTOR": "1",
            "QT_FONT_DPI": "96",
            "QT_FORCE_STDERR_LOGGING": "1",
            "QML_DISABLE_DISK_CACHE": "1",
            "QML_XHR_ALLOW_FILE_READ": "1",
        }
        env.pop("QT_QUICK_BACKEND", None)
        if args.backend == "software":
            env["QT_QUICK_BACKEND"] = "software"
        else:
            env["QT_QUICK_BACKEND"] = "rhi"
            env["QSG_RHI_BACKEND"] = "opengl"
        command = [runner, "-input", str(test)]
        if args.case:
            command.append("VisualizerViewSnapshots::test_snapshots:" + args.case)
        result = subprocess.run(command, check=False, env=env, timeout=120)
        print(f"Before/after snapshots: {output}", flush=True)
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
