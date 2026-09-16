#!/usr/bin/env python3
"""Read desktop power telemetry without changing the widget or requiring root.

Run once with the widget stopped and again while visible, keeping other work
unchanged: python3 tools/measure_power.py --seconds 10
Add --json for machine-readable output. Quickshell is optional; --qs can select
its executable when it is not on PATH. All sensor and runtime access is read-only.
"""

import argparse
import configparser
import glob
import json
import math
import os
import re
import shutil
import statistics
import subprocess
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except (OSError, UnicodeError):
        return None


def read_number(path):
    try:
        value = float(read_text(path))
        return value if math.isfinite(value) else None
    except (TypeError, ValueError):
        return None


def summary(values):
    if not values:
        return None
    return {
        key: round(value, 3)
        for key, value in {
            "average": statistics.mean(values),
            "minimum": min(values),
            "maximum": max(values),
        }.items()
    }


def energy_delta(previous, current, maximum):
    if previous is None or current is None:
        return None
    delta = current - previous
    if delta < 0:
        if not maximum or not (0 <= previous < maximum and 0 <= current < maximum):
            return None
        delta += maximum
    return delta


def sensors():
    energy, temperatures, frequencies = {}, {}, {}
    seen = set()
    for path in sorted(Path("/sys/class/powercap").glob("*/energy_uj")):
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen.add(resolved)
        label = read_text(path.parent / "name") or path.parent.name
        energy[f"{path.parent.name}/{label}"] = (
            path,
            read_number(path.parent / "max_energy_range_uj"),
        )
    for path in sorted(Path("/sys/class/hwmon").glob("hwmon*/temp*_input")):
        driver = read_text(path.parent / "name")
        if driver not in {"coretemp", "k10temp", "zenpower", "amdgpu", "i915", "xe"}:
            continue
        label = (
            read_text(path.with_name(path.name.replace("_input", "_label")))
            or path.stem
        )
        temperatures[f"{path.parent.name}/{driver}/{label}"] = path
    for pattern in (
        "/sys/class/drm/card*/gt_act_freq_mhz",
        "/sys/class/drm/card*/gt_cur_freq_mhz",
        "/sys/class/drm/card*/gt/gt*/rps_act_freq_mhz",
        "/sys/class/drm/card*/gt/gt*/rps_cur_freq_mhz",
        "/sys/class/drm/card*/device/tile*/gt*/freq*/act_freq",
        "/sys/class/drm/card*/device/tile*/gt*/freq*/cur_freq",
    ):
        for name in sorted(glob.glob(pattern)):
            path = Path(name)
            frequencies[str(path.relative_to("/sys/class/drm"))] = path
    return energy, temperatures, frequencies


def widget_status(runtime):
    run = runtime / "audio-wave-quickshell"
    result = {
        name: read_text(run / name) for name in ("status", "publisher", "feeder.pid")
    }
    configuration = configparser.ConfigParser()
    try:
        configuration.read_string(read_text(run / "cava.conf") or "")
        result["capture"] = {
            key: configuration.get(section, key, fallback=None)
            for section, key in (
                ("general", "framerate"),
                ("general", "bars"),
                ("input", "method"),
                ("input", "active"),
                ("general", "sleep_timer"),
            )
        }
    except configparser.Error:
        result["capture"] = None
    try:
        result["frame_age_seconds"] = round(
            time.time() - (run / "frame.ini").stat().st_mtime, 3
        )
    except OSError:
        result["frame_age_seconds"] = None
    return result


def quickshell_status(executable, config, runtime):
    if not executable:
        return {
            "available": False,
            "reason": "qs is not on PATH; optional --qs PATH enables log inspection",
        }
    try:
        listed = subprocess.run(
            [executable, "-p", str(config), "list", "--json"],
            capture_output=True,
            text=True,
            timeout=3,
            check=True,
        )
        instances = json.loads(listed.stdout)
    except (OSError, subprocess.SubprocessError, ValueError):
        return {
            "available": False,
            "reason": "Could not read this configuration's Quickshell instance list",
        }
    result = {
        "available": True,
        "instances": [
            {key: item.get(key) for key in ("id", "pid", "launch_time")}
            for item in instances
        ],
    }
    renderer = []
    if instances:
        latest = max(instances, key=lambda item: item.get("launch_time", ""))
        instance_id = str(latest.get("id", ""))
        if re.fullmatch(r"[A-Za-z0-9_-]+", instance_id):
            log_path = runtime / "quickshell/by-id" / instance_id / "log.qslog"
            try:
                log = subprocess.run(
                    [
                        executable,
                        "log",
                        "--no-color",
                        "--rules",
                        "qt.scenegraph.general.debug=true;qt.rhi.*.debug=true",
                        str(log_path),
                    ],
                    capture_output=True,
                    text=True,
                    timeout=3,
                    check=True,
                )
                for line in (log.stdout + log.stderr).splitlines():
                    # Only renderer diagnostics, never media metadata or other
                    # applications' log messages. These describe the actual boot.
                    if re.search(r"qt\.(scenegraph\.general|rhi[.:])", line):
                        clean = re.sub(r"\x1b\[[0-9;]*m", "", line).strip()
                        if clean not in renderer:
                            renderer.append(clean)
            except (OSError, subprocess.SubprocessError):
                pass
    result["renderer_log"] = renderer[:40]
    if instances and not renderer:
        result["renderer_note"] = (
            "This instance's log has no captured renderer diagnostics"
        )
    return result


def measure(seconds, interval, runtime):
    energy, temperatures, frequencies = sensors()
    power_values = {key: [] for key in energy}
    energy_totals = {key: [0, 0] for key in energy}
    temperature_values = {key: [] for key in temperatures}
    frequency_values = {key: [] for key in frequencies}
    previous = {key: read_number(path) for key, (path, _) in energy.items()}
    initial_status = widget_status(runtime)
    start = previous_time = time.monotonic()
    samples = 0
    while previous_time - start < seconds:
        time.sleep(min(interval, max(0, seconds - (time.monotonic() - start))))
        now = time.monotonic()
        duration = now - previous_time
        for key, (path, maximum) in energy.items():
            current = read_number(path)
            delta = energy_delta(previous[key], current, maximum)
            if delta is not None:
                power_values[key].append(delta / 1_000_000 / duration)
                energy_totals[key][0] += delta
                energy_totals[key][1] += duration
            previous[key] = current
        for paths, values, divisor in (
            (temperatures, temperature_values, 1000),
            (frequencies, frequency_values, 1),
        ):
            for key, path in paths.items():
                value = read_number(path)
                if value is not None:
                    values[key].append(value / divisor)
        samples += 1
        previous_time = now
    power = {key: summary(values) for key, values in power_values.items()}
    for key, (total, duration) in energy_totals.items():
        if power[key] is not None:
            power[key]["average"] = round(total / 1_000_000 / duration, 3)
    return {
        "seconds": round(previous_time - start, 3),
        "samples": samples,
        "scope": "Whole hardware domains, including the compositor and other running work; overlapping domains must not be added",
        "power_watts": power,
        "temperature_celsius": {
            key: summary(values) for key, values in temperature_values.items()
        },
        "gpu_frequency_mhz": {
            key: summary(values) for key, values in frequency_values.items()
        },
        "widget_before": initial_status,
        "widget_after": widget_status(runtime),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=10)
    parser.add_argument("--interval", type=float, default=1)
    parser.add_argument("--json", action="store_true")
    parser.add_argument(
        "--qs", default=shutil.which("qs") or shutil.which("quickshell")
    )
    parser.add_argument("--config", type=Path, default=REPO / "shell.qml")
    args = parser.parse_args()
    if not (0 < args.seconds <= 60 and 0 < args.interval <= args.seconds):
        parser.error(
            "seconds must be 0–60 and interval must be positive and no longer than seconds"
        )
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    # Read logs before the measurement so decoding them does not affect samples.
    instance = quickshell_status(args.qs, args.config.resolve(), runtime)
    result = measure(args.seconds, args.interval, runtime)
    result["quickshell"] = instance
    if args.json:
        print(json.dumps(result, indent=2))
        return
    print(f"Measured {result['seconds']:.2f}s ({result['samples']} samples)")
    print(result["scope"])
    for group, unit in (
        ("power_watts", "W"),
        ("temperature_celsius", "°C"),
        ("gpu_frequency_mhz", "MHz"),
    ):
        for label, values in result[group].items():
            if values is None:
                print(f"{label}: unavailable")
            else:
                print(
                    f"{label}: average {values['average']:.2f} {unit}; "
                    f"min {values['minimum']:.2f}, max {values['maximum']:.2f}"
                )
    print("Widget before:", json.dumps(result["widget_before"]))
    print("Widget after: ", json.dumps(result["widget_after"]))
    print("Quickshell:  ", json.dumps(instance))


if __name__ == "__main__":
    main()
