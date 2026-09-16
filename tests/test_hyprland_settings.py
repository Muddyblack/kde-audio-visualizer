#!/usr/bin/env python3
"""Load the real shell/settings UI offscreen; exercise persistence and defaults."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
qs = shutil.which("qs")
if not qs:
    raise SystemExit("Quickshell (qs) must be on PATH")
with tempfile.TemporaryDirectory(prefix="audio-settings-test-") as directory:
    root = Path(directory)
    shutil.copytree(repo / "package", root / "package")
    shutil.copytree(repo / "hyprland", root / "hyprland")
    shell = root / "hyprland/AudioVisualizerShell.qml"
    # Only replace the unavailable headless layer surface; all application
    # bindings, settings controls, persistence and shared rendering stay real.
    text = shell.read_text().replace("PanelWindow {", "FloatingWindow {")
    text = "\n".join(
        line
        for line in text.splitlines()
        if not any(
            token in line
            for token in [
                "anchors.top: true",
                "margins.top:",
                "exclusionMode:",
                "WlrLayershell.",
            ]
        )
    )
    shell.write_text(text)
    (root / "defaults.json").write_text('{"sensitivity": 130, "alwaysVisible": false}')
    env = os.environ | {
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QPA_PLATFORMTHEME": "generic",
        "QT_QUICK_CONTROLS_STYLE": "Basic",
        "QT_QUICK_BACKEND": "software",
        "XDG_RUNTIME_DIR": directory,
        "XDG_CONFIG_HOME": directory,
        "AUDIO_WAVE_DEFAULTS": str(root / "defaults.json"),
    }
    for phase in [0, 1]:
        if phase == 1:
            # Explicit declarative rates override the lower desktop default;
            # a saved GUI rate still overrides both until Reset.
            (root / "defaults.json").write_text(
                '{"sensitivity": 130, "alwaysVisible": false, "framerate": 30, "detailFields": ["format"]}'
            )
        (root / "shell.qml").write_text(
            """import QtQuick
import "hyprland"
AudioVisualizerShell {
    id: shell
    Timer {
        interval: 300
        running: true
        onTriggered: {
            if (shell.configuration.sensitivity !== EXPECTED) console.log("FAIL: defaults/persistence");
            if (shell.configuration.framerate !== EXPECTED_RATE) console.log("FAIL: frame-rate precedence");
            if (JSON.stringify(shell.configuration.detailFields) !== JSON.stringify(EXPECTED_FIELDS)) console.log("FAIL: StringList defaults/persistence");
            if (shell.configuration.hAnchor !== EXPECTED_ANCHOR) console.log("FAIL: horizontal anchor defaults/persistence");
            if (shell.configuration.layoutMode !== EXPECTED_LAYOUT) console.log("FAIL: layout defaults/persistence");
            shell.configure();
            shell.saveSettings(OVERRIDES);
        }
    }
    Timer {
        interval: 900
        running: true
        onTriggered: {
            if (shell.configuration.framerate !== SAVED_RATE) console.log("FAIL: saved/reset frame rate");
            if (JSON.stringify(shell.configuration.detailFields) !== JSON.stringify(SAVED_FIELDS)) console.log("FAIL: saved/reset StringList");
            if (shell.configuration.hAnchor !== SAVED_ANCHOR) console.log("FAIL: saved/reset horizontal anchor");
            if (shell.configuration.layoutMode !== SAVED_LAYOUT) console.log("FAIL: saved/reset layout");
            console.log("SETTINGS TEST COMPLETE"); Qt.quit();
        }
    }
}
""".replace("EXPECTED_RATE", "15" if phase == 0 else "5")
            .replace("SAVED_RATE", "5" if phase == 0 else "30")
            .replace(
                "EXPECTED_FIELDS",
                '["album", "genre", "format", "player"]'
                if phase == 0
                else '["player", "album"]',
            )
            .replace(
                "SAVED_FIELDS", '["player", "album"]' if phase == 0 else '["format"]'
            )
            .replace("EXPECTED_ANCHOR", '"center"' if phase == 0 else '"right"')
            .replace("SAVED_ANCHOR", '"right"' if phase == 0 else '"center"')
            .replace("EXPECTED_LAYOUT", '"classic"' if phase == 0 else '"poster"')
            .replace("SAVED_LAYOUT", '"poster"' if phase == 0 else '"classic"')
            .replace("EXPECTED", "130" if phase == 0 else "175")
            .replace(
                "OVERRIDES",
                '{monitor: "all", sensitivity: 175, framerate: 5, detailFields: ["player", "album"], hAnchor: "right", layoutMode: "poster"}'
                if phase == 0
                else "{}",
            )
        )
        result = subprocess.run(
            [qs, "-p", directory], env=env, capture_output=True, text=True, timeout=8
        )
        log = result.stdout + result.stderr
        assert result.returncode == 0 and "SETTINGS TEST COMPLETE" in log, log
        assert not any(
            token in log
            for token in [
                "FAIL:",
                "Failed to load configuration",
                "ReferenceError",
                "TypeError",
                "Unable to assign",
                "Binding loop",
            ]
        ), log
        saved = json.loads((root / "audio-wave-visualizer/hyprland.json").read_text())
        if phase == 0:
            assert saved == {
                "monitor": "all",
                "sensitivity": 175,
                "framerate": 5,
                "detailFields": ["player", "album"],
                "hAnchor": "right",
                "layoutMode": "poster",
            }, saved
        else:
            assert saved == {}, saved
    print(
        "PASS: real settings UI, Nix defaults, scalar/StringList overrides, reload and reset"
    )
