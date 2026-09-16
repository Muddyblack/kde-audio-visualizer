#!/usr/bin/env python3
"""The Waybar module prints valid JSON for playerctl metadata lines."""

import json
import os
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix="audio-waybar-test-") as directory:
    binaries = Path(directory)
    (binaries / "lines").write_text(
        'Playing\x1fspotify\x1fThe "Band"\x1fSay \\ Hi\x1fAlbum\n'
        "Paused\x1fmpv\x1f\x1fOnly title\x1f\n"
    )
    fake = binaries / "playerctl"
    fake.write_text('#!/bin/sh\ncat "$(dirname "$0")/lines"\n')
    fake.chmod(0o755)
    output = subprocess.run(
        ["bash", str(REPO / "hyprland/run.sh"), "--waybar"],
        env=os.environ | {"PATH": f"{binaries}{os.pathsep}{os.environ['PATH']}"},
        capture_output=True,
        text=True,
        timeout=10,
        check=True,
    ).stdout
    rows = [json.loads(line) for line in output.splitlines()]
    assert rows[0] == {"text": "", "tooltip": "", "class": "stopped", "alt": ""}, rows[
        0
    ]
    assert rows[1]["text"] == 'Say \\ Hi · The "Band"', rows[1]
    assert rows[1]["class"] == "playing" and rows[1]["alt"] == "spotify", rows[1]
    assert rows[1]["tooltip"] == 'Say \\ Hi\nThe "Band"\nAlbum\nspotify', rows[1]
    assert rows[2]["text"] == "Only title" and rows[2]["class"] == "paused", rows[2]
    print("PASS: Waybar JSON lines, escaping and playback classes")
