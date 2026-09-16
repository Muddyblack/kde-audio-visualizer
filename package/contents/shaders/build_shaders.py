#!/usr/bin/env python3
"""Assemble the common GLSL prelude and bake every ShaderEffect family."""

import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile


SHADER_DIR = Path(__file__).resolve().parent
FAMILIES = (
    "visualizer",
    "viz_linear",
    "viz_radial",
    "viz_particles",
    "viz_ribbon",
    "viz_orbit",
    "text_fade",
)
QSB_FLAGS = ("--glsl", "100es,120,150", "--hlsl", "50", "--msl", "12")


def build(output_dir, qsb="qsb"):
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    common = (SHADER_DIR / "viz_common.glsl").read_text()
    with tempfile.TemporaryDirectory(prefix="audio-visualizer-glsl-") as directory:
        for family in FAMILIES:
            source = Path(directory) / f"{family}.frag"
            prelude = common.replace(
                "#version 440\n", f"#version 440\n#define {family.upper()} 1\n", 1
            )
            source.write_text(
                ("" if family in ("viz_orbit", "text_fade") else prelude + "\n")
                + (SHADER_DIR / f"{family}.frag").read_text()
            )
            subprocess.run(
                [
                    qsb,
                    *QSB_FLAGS,
                    "-o",
                    str(output_dir / f"{family}.frag.qsb"),
                    str(source),
                ],
                check=True,
            )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=SHADER_DIR)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify checked-in packages without modifying them",
    )
    args = parser.parse_args()
    qsb = shutil.which("qsb")
    if not qsb:
        raise SystemExit(
            "qsb is required; run make shaders in the Qt development environment"
        )
    if args.check:
        with tempfile.TemporaryDirectory(prefix="audio-visualizer-qsb-") as directory:
            build(directory, qsb)
            for family in FAMILIES:
                name = f"{family}.frag.qsb"
                if (Path(directory) / name).read_bytes() != (
                    SHADER_DIR / name
                ).read_bytes():
                    raise SystemExit(f"{name} is out of date: run make shaders")
                print(
                    f"PASS: compiled shader matches {family}.frag"
                    + (
                        ""
                        if family in ("viz_orbit", "text_fade")
                        else " + viz_common.glsl"
                    )
                )
    else:
        build(args.output_dir, qsb)


if __name__ == "__main__":
    main()
