#!/usr/bin/env python3
"""Compare new QML visualizers with drawWave extracted from the HTML prototype.

Headless geometry check (the HTML drawing code runs on Qt Canvas):
  python3 tools/compare_html_visualizers.py --reference qt

Actual Chromium/Qt pixel comparison, including bloom, on a desktop:
  python3 tools/compare_html_visualizers.py --reference chromium \
      --backend opengl --platform xcb --renderer shader --glow

The Qt reference verifies the drawing formulas on the same raster engine. It
does NOT verify Chromium rasterization or browser shadows. Chromium is the
browser oracle. Every run writes the extracted HTML, deterministic inputs,
PNG pairs, absolute difference images, and measured pixel errors. A nonzero
pixel error is never described as an exact match. Qt source comparisons require
zero pixel error by default. Chromium comparisons measure differences without
a fitted pass threshold; --max-rmse sets a reviewer-chosen acceptable error.

Types 0-5 retain their existing appearance and deliberately differ from the
prototype; this comparison covers new types 6-15. Audio smoothing is outside
this geometry comparison: both sides receive identical final bar levels,
bands, time, peaks, particles, and ripples. Random creation is disabled.
"""

import argparse
import base64
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
STYLES = (
    "peak-bars",
    "led-meter",
    "mountain",
    "oscilloscope",
    "layered-wave",
    "radial-burst",
    "pixel-matrix",
    "pulse-orb",
    "sparkles",
    "silk-ribbon",
)


def reference_source(html):
    """Extract source, replacing only random creation with a test callback."""
    helpers = html[
        html.index("function hexRgb(") : html.index("/* ─── canvas animation")
    ]
    canvas = html[
        html.index("function prepCanvas(") : html.index("// Radial visualizers with")
    ]
    return (helpers + "\nconst memo = new Map();\n" + canvas).replace(
        "Math.random()", "referenceRandom()"
    )


def cases(args):
    result = []
    for style in range(6, 16):
        if args.style is not None and style != args.style:
            continue
        variants = [(320, 64, "default"), (64, 20, "mini"), (320, 64, "palette")]
        if args.extended:
            variants += [(320, 64, "rainbow"), (320, 64, "cover")]
            if style in (6, 7, 8):
                variants.append((320, 64, "down"))
        for width, height, variant in variants:
            count = max(6, min(24, width // (4 if style in (7, 12, 14) else 2.5)))
            count = int(count)
            samples = [
                120,
                380,
                620,
                540,
                300,
                820,
                910,
                700,
                450,
                260,
                180,
                520,
                760,
                640,
                400,
                350,
                580,
                830,
                690,
                420,
                240,
                160,
                300,
                90,
            ][:count]
            levels = []
            for i, sample in enumerate(samples):
                p = i / (count - 1)
                weight = p / 0.15 if p < 0.15 else (1 - p) / 0.15 if p > 0.85 else 1
                taper = 0.5 - 0.5 * math.cos(weight * math.pi) if weight < 1 else 1
                levels.append(sample / 1000 * taper)
            result.append(
                {
                    "tag": f"{style:02d}-{STYLES[style - 6]}-{variant}",
                    "style": style,
                    "width": width,
                    "height": height,
                    "samples": samples,
                    "levels": levels,
                    "peaks": [min(1, value + 0.13) for value in levels],
                    "particles": [
                        {
                            "x": width * 0.24,
                            "y": height * 0.23,
                            "vy": -0.7,
                            "r": 1.2,
                            "life": 0.8,
                        },
                        {
                            "x": width * 0.51,
                            "y": height * 0.61,
                            "vy": -1.1,
                            "r": 1.8,
                            "life": 0.45,
                        },
                        {
                            "x": width * 0.76,
                            "y": height * 0.34,
                            "vy": -0.4,
                            "r": 0.8,
                            "life": 0.95,
                        },
                    ],
                    "ripples": [{"x": width * 0.62, "age": 0.37}],
                    "time": 2.375,
                    "bass": 0.63,
                    "mid": 0.72,
                    "high": 0.48,
                    "settings": {
                        "visualizerType": style,
                        "numBars": count,
                        "sensitivity": 100,
                        "noiseReduction": 0.77,
                        "lineWidth": 1.8,
                        "fillWave": True,
                        "glowWave": args.glow,
                        "bloom": 1.3 if variant == "palette" else 1,
                        "batterySaver": False,
                        "idleAmbient": False,
                        "reducedMotion": args.reduced_motion,
                        "ribbonCurvature": 1,
                        "ribbonFullness": 1,
                        "hueReactive": variant == "palette",
                        "vizColorMode": variant
                        if variant in ("palette", "cover", "rainbow")
                        else "solid",
                        "vizPalette": "aurora",
                        "vizDirection": "down" if variant == "down" else "up",
                    },
                }
            )
    return result


HARNESS = r"""
var fixture;
function referenceRandom() { return 1; }
function derive() {
    return {playing: true, accent: '#b4befe', t: {pal: {p1: '#5ef2c1', p2: '#b57bff'}}};
}
function configure(row) {
    fixture = row;
    // Undo drawWave's one-frame state decay so the rendered state equals QML.
    memo.set('fixture', {
        v: row.levels.slice(),
        peak: row.peaks.map(p => p + .01), energy: 1, amp: 0,
        parts: row.particles.map(p => ({x:p.x, y:p.y-p.vy, vy:p.vy, r:p.r, life:p.life+.025})),
        ripples: row.ripples.map(r => ({x:r.x, age:r.age-.03}))
    });
    spectrum = function(i) { return row.levels[i]; };
    bands = function() { return {bass:row.bass, mid:row.mid, high:row.high, attack:false}; };
}
function render(canvas, row) {
    configure(row);
    // sm=1 bypasses the prototype's synthetic audio smoothing. The renderer
    // receives the same final (double-precision) levels as its QML counterpart.
    const settings = Object.assign({},row.settings,{noiseReduction:(1-.3)/.62});
    drawWave({el:canvas, key:'fixture', getS:() => settings, getStatus:() => 'playing'}, row.time);
}
"""

# Qt's Canvas exposes the pre-standard ellipse/roundedRect APIs. This adapter
# translates only browser API calls; the drawing formulas stay unchanged.
QT_ADAPTER = r"""
function cssColor(value) {
    if (typeof value !== 'string') return value;
    // Qt's CSS parser quantizes rgba alpha to 8 bits and rejects hsl. Preserve
    // the supplied floating-point CSS components through QColor's APIs.
    const rgba = /^rgba?\((.*)\)$/.exec(value);
    if (rgba) {
        const parts = rgba[1].split(',');
        return Qt.rgba(parseFloat(parts[0])/255,parseFloat(parts[1])/255,
            parseFloat(parts[2])/255,parts.length>3?parseFloat(parts[3]):1);
    }
    const match = /^hsla?\((.*)\)$/.exec(value);
    if (!match) return value;
    const parts = match[1].split(',');
    return Qt.hsla(((parseFloat(parts[0]) % 360) + 360) % 360 / 360,
        parseFloat(parts[1])/100, parseFloat(parts[2])/100,
        parts.length > 3 ? parseFloat(parts[3]) : 1);
}
function browserContext(ctx) {
    const out = {};
    const methods = ['setTransform','clearRect','createLinearGradient','createRadialGradient',
        'beginPath','moveTo','lineTo','quadraticCurveTo','bezierCurveTo','arc','arcTo',
        'rect','closePath','save','restore','fill','stroke','fillRect','translate','rotate','scale'];
    methods.forEach(name => out[name] = function() { return ctx[name].apply(ctx, arguments); });
    ['lineJoin','lineCap','lineWidth','shadowColor','shadowBlur','strokeStyle','fillStyle',
        'globalAlpha','globalCompositeOperation'].forEach(name => Object.defineProperty(out, name,
        {get:() => ctx[name], set:value => {
            ctx[name] = value && value._gradient ? value._gradient :
                ['shadowColor','strokeStyle','fillStyle'].includes(name) ? cssColor(value) : value;
        }}));
    ['createLinearGradient','createRadialGradient'].forEach(name => {
        out[name] = function() {
            const gradient = ctx[name].apply(ctx, arguments);
            return {_gradient:gradient, addColorStop:(offset,color) => gradient.addColorStop(offset,cssColor(color))};
        };
    });
    out.roundRect = function(x, y, w, h, r) {
        ctx.moveTo(x+r,y); ctx.lineTo(x+w-r,y); ctx.arcTo(x+w,y,x+w,y+r,r);
        ctx.lineTo(x+w,y+h-r); ctx.arcTo(x+w,y+h,x+w-r,y+h,r);
        ctx.lineTo(x+r,y+h); ctx.arcTo(x,y+h,x,y+h-r,r);
        ctx.lineTo(x,y+r); ctx.arcTo(x,y,x+r,y,r); ctx.closePath();
    };
    out.ellipse = function(x,y,rx,ry,rotation,start,end) {
        ctx.save(); ctx.translate(x,y); ctx.rotate(rotation); ctx.scale(rx,ry);
        ctx.arc(0,0,1,start,end); ctx.restore();
    };
    return out;
}
prepCanvas = function(e) {
    const c = e.el, ctx = c.getContext('2d');
    ctx.reset();
    return {ctx:browserContext(ctx), w:c.width, h:c.height, k:1};
};
"""


def write_html(output, source, fixtures):
    page = (
        """<!doctype html><meta charset="utf-8"><title>HTML visualizer reference</title>
<style>body{background:#20232b;color:#fff;font:14px sans-serif}canvas{display:block;margin:8px 0 24px}</style>
<h1>Actual prototype drawWave, deterministic frames</h1><div id="images"></div><pre id="results"></pre><script>
"""
        + source
        + HARNESS
        + "\nconst fixtures = "
        + json.dumps(fixtures)
        + r""";
const results = {};
for (const row of fixtures) {
    const label = document.createElement('div'); label.textContent = row.tag;
    document.querySelector('#images').appendChild(label);
    const canvas = document.createElement('canvas');
    canvas.style.width = row.width + 'px'; canvas.style.height = row.height + 'px';
    document.querySelector('#images').appendChild(canvas);
    render(canvas, row);
    const down = row.settings.vizDirection === 'down' && [6,7,8].includes(row.style);
    if (down) canvas.style.transform = 'scaleY(-1)';
    const combined = document.createElement('canvas'); combined.width=row.width; combined.height=row.height;
    const ctx=combined.getContext('2d'); ctx.fillStyle='#20232b'; ctx.fillRect(0,0,row.width,row.height);
    if (down) { ctx.translate(0,row.height); ctx.scale(1,-1); }
    ctx.drawImage(canvas,0,0,row.width,row.height);
    results[row.tag] = combined.toDataURL('image/png').split(',')[1];
}
document.querySelector('#results').textContent = JSON.stringify(results);
</script>
"""
    )
    (output / "reference.html").write_text(page)


def browser_capture(args, output):
    browser = args.browser or next(
        (
            shutil.which(name)
            for name in ("chromium", "chromium-browser", "google-chrome")
            if shutil.which(name)
        ),
        None,
    )
    if not browser:
        raise RuntimeError("Chromium/Chrome is required for --reference chromium")
    with tempfile.TemporaryDirectory(prefix="audio-html-chrome-") as profile:
        # Current Chrome hangs in --dump-dom with legacy --headless or with the
        # crash-reporter/crashpad disabling flags.
        command = [
            browser,
            "--headless=new",
            "--virtual-time-budget=5000",
            "--disable-gpu",
            "--disable-dev-shm-usage",
            "--no-first-run",
            "--no-default-browser-check",
            "--force-device-scale-factor=1",
            f"--user-data-dir={profile}",
            "--dump-dom",
            (output / "reference.html").as_uri(),
        ]
        if args.browser_no_sandbox:
            command.insert(1, "--no-sandbox")
        result = subprocess.run(command, check=False, capture_output=True, text=True, timeout=40)
        (output / "chromium.log").write_text(result.stderr)
        if result.returncode:
            raise RuntimeError(
                f"Chromium exited {result.returncode}; see {output / 'chromium.log'}"
            )
        match = re.search(r'<pre id="results">([^<]+)</pre>', result.stdout)
        if not match:
            (output / "chromium-dom.html").write_text(result.stdout)
            raise RuntimeError(
                "Chromium did not return rendered PNGs; see chromium-dom.html"
            )
        for tag, encoded in json.loads(match[1]).items():
            (output / f"{tag}-browser.png").write_bytes(
                base64.b64decode(encoded, validate=True)
            )


def write_report(output, measurements, args):
    heading = (
        "HTML source on Qt Canvas" if args.reference == "qt" else "Chromium Canvas"
    )
    rows = []
    for measurement in measurements:
        tag = measurement["tag"]
        rows.append(
            f"<tr><th>{tag}<small>RMSE {measurement['rmse']:.6f}; "
            f"{measurement['changedPixels']} changed pixels; exact: {measurement['exact']}</small></th>"
            + "".join(
                f'<td><img src="{tag}-{kind}.png"></td>'
                for kind in ("reference", "qml", "difference")
            )
            + "</tr>"
        )
    (output / "report.html").write_text(
        """<!doctype html><meta charset="utf-8"><title>Visualizer comparison</title>
<style>body{background:#14161b;color:#ddd;font:14px sans-serif}table{border-collapse:collapse}td,th{padding:10px;border-bottom:1px solid #444;text-align:left}small{display:block;font-weight:400;margin-top:6px}img{image-rendering:auto}</style>
"""
        + f"<h1>{heading} versus QML {args.renderer}</h1>"
        + (
            "<p>This checks source geometry on Qt. Actual Chromium pixels and GPU bloom remain unverified.</p>"
            if args.reference == "qt"
            else ""
        )
        + "<p>RMSE is normalized RGB root mean square error. Only zero changed pixels means an exact match. Difference images show absolute RGB errors.</p>"
        + f"<table><tr><th>Fixture</th><th>{heading}</th><th>QML</th><th>Difference</th></tr>"
        + "\n".join(rows)
        + "</table>"
    )


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--reference", choices=("qt", "chromium"), default="qt")
    parser.add_argument("--renderer", choices=("canvas", "shader"), default="canvas")
    parser.add_argument(
        "--backend", choices=("software", "opengl", "vulkan"), default="software"
    )
    parser.add_argument("--platform", default="offscreen")
    parser.add_argument("--html", type=Path, default=REPO / "docs/website/index.html")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--style", type=int, choices=range(6, 16))
    parser.add_argument(
        "--extended",
        action="store_true",
        help="Also compare cover/rainbow colours and hanging bars (53 cases)",
    )
    parser.add_argument(
        "--reduced-motion",
        action="store_true",
        help="Audit reduced-motion differences: the widget freezes more phases than the prototype",
    )
    parser.add_argument("--glow", action="store_true")
    parser.add_argument("--browser")
    parser.add_argument(
        "--browser-no-sandbox",
        action="store_true",
        help="For isolated CI containers that require this Chromium flag",
    )
    parser.add_argument(
        "--max-rmse",
        type=float,
        help="Normalized RGB tolerance (0..1); default zero for Qt, measurement only for Chromium",
    )
    args = parser.parse_args()
    if args.max_rmse is not None and not 0 <= args.max_rmse <= 1:
        parser.error("--max-rmse must be between 0 and 1")
    if args.max_rmse is None and args.reference == "qt":
        args.max_rmse = 0
    if args.renderer == "shader" and args.backend == "software":
        parser.error("Shader comparison requires --backend opengl or vulkan")
    if args.glow and args.reference == "qt":
        parser.error(
            "Qt source comparison covers geometry; use Chromium and a GPU backend for bloom"
        )
    if args.glow and args.backend == "software":
        parser.error("Bloom comparison requires --backend opengl or vulkan")
    runner = shutil.which("qmltestrunner")
    if not runner:
        parser.error("Qt 6 qmltestrunner must be on PATH")
    output = (
        args.output.resolve()
        if args.output
        else Path(tempfile.mkdtemp(prefix="audio-html-comparison-"))
    )
    output.mkdir(parents=True, exist_ok=True)
    html = args.html.read_text()
    if "function hexRgb(" not in html:
        app_js = args.html.parent / "app.js"
        if app_js.exists():
            html = app_js.read_text()
    source = reference_source(html)
    fixtures = cases(args)
    (output / "fixtures.json").write_text(json.dumps(fixtures, indent=2) + "\n")
    (output / "manifest.json").write_text(
        json.dumps(
            {
                "reference": args.reference,
                "renderer": args.renderer,
                "backend": args.backend,
                "glow": args.glow,
                "extended": args.extended,
                "reduced_motion": args.reduced_motion,
                "html": str(args.html),
                "html_sha256": hashlib.sha256(html.encode()).hexdigest(),
                "scope": "styles 6-15, deterministic drawing state; excludes live audio analysis",
                "limitation": "Qt reference uses the Qt rasterizer; browser pixels and bloom require Chromium"
                if args.reference == "qt"
                else "",
            },
            indent=2,
        )
        + "\n"
    )
    write_html(output, source, fixtures)
    if args.reference == "chromium":
        try:
            browser_capture(args, output)
        except (RuntimeError, subprocess.TimeoutExpired) as error:
            raise SystemExit(
                f"Browser comparison NOT RUN: {error}\nReproducible inputs: {output}"
            ) from error
    with tempfile.TemporaryDirectory(prefix="audio-html-qt-") as directory:
        runtime = Path(directory)
        (runtime / "Reference.js").write_text(source + HARNESS + QT_ADAPTER)
        template = (
            REPO / "tests/snapshots/HtmlVisualizerComparison.qml.in"
        ).read_text()
        replacements = {
            "UI": (REPO / "package/contents/ui").as_uri(),
            "OUTPUT": str(output),
            "FIXTURES": fixtures,
            "REFERENCE": args.reference,
            "RENDERER": args.renderer,
            "BACKEND": args.backend,
            "MAX_RMSE": args.max_rmse,
        }
        for key, value in replacements.items():
            template = template.replace(f"@{key}@", json.dumps(value))
        test = runtime / "tst_htmlcomparison.qml"
        test.write_text(template)
        env = os.environ | {
            "QT_QPA_PLATFORM": args.platform,
            "QT_QPA_PLATFORMTHEME": "generic",
            "QT_QUICK_CONTROLS_STYLE": "Basic",
            "QT_SCALE_FACTOR": "1",
            "QT_FONT_DPI": "96",
            "QML_DISABLE_DISK_CACHE": "1",
        }
        if args.platform == "offscreen":
            env["XDG_RUNTIME_DIR"] = directory
        env.pop("QT_QUICK_BACKEND", None)
        if args.backend == "software":
            env["QT_QUICK_BACKEND"] = "software"
        else:
            env["QSG_RHI_BACKEND"] = args.backend
        result = subprocess.run(
            [runner, "-input", str(test)],
            check=False, env=env,
            capture_output=True,
            text=True,
            timeout=120,
        )
        (output / "qml.log").write_text(result.stdout + result.stderr)
        print(result.stdout + result.stderr, end="")
        measurements = [
            json.loads(line.split("HTML_METRIC ", 1)[1])
            for line in result.stdout.splitlines()
            if "HTML_METRIC " in line
        ]
        (output / "metrics.json").write_text(json.dumps(measurements, indent=2) + "\n")
        write_report(output, measurements, args)
        if measurements:
            exact = sum(row["exact"] for row in measurements)
            maximum = max(row["rmse"] for row in measurements)
            print(
                f"Measured {len(measurements)} pairs: {exact} exact; maximum normalized RGB RMSE {maximum:.6f}."
            )
        print(f"Reference, QML, and difference PNGs: {output}")
        if args.reference == "qt":
            print(
                "Qt source/geometry comparison only. Chromium pixels and GPU bloom remain unverified."
            )
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
