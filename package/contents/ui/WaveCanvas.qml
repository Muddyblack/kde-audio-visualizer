import QtQuick 2.15
import QtQuick.Effects
import "../code/WaveMath.js" as WaveMath
import "../code/WaveDraw.js" as WaveDraw

Canvas {
    id: wave

    property var bars: []
    property int numBars: bars.length
    property real maxRange: 1000
    property bool hasAudio: false
    property bool backendFailed: false
    property color waveColor: "#ffffff"
    property color textColor: "#ffffff"
    property real lineWidth: 2
    property bool fillWave: true
    property bool glowWave: true
    property int visualizerType: 0
    property real visualFrameTime: 0
    property real bass: 0
    property real mid: 0
    property real high: 0
    property real energy: 1
    property bool reducedMotion: false
    property string vizDirection: "up"
    property string vizColorMode: "solid"
    property string vizPalette: "aurora"
    property bool hueReactive: false
    property real bloom: 1
    property real ribbonCurvature: 1
    property real ribbonFullness: 1
    property color coverColor1: "#b4befe"
    property color coverColor2: "#b4befe"
    property var peaks: []
    property var particles: []
    property var ripples: []
    property bool edgeFade: false
    readonly property var colorStops: WaveMath.colorStops(waveColor, vizColorMode, vizPalette, coverColor1, coverColor2, hueReactive, hueReactive && !reducedMotion ? high : .5, !reducedMotion && (hueReactive || vizColorMode === "rainbow") ? visualFrameTime / 1000 : 0, reducedMotion)
    readonly property bool _colored: vizColorMode !== "solid" || hueReactive
    readonly property color _mainColor: _colored ? colorStops[0] : waveColor
    readonly property int _sampleCount: WaveMath.count(numBars, width, visualizerType)

    antialiasing: true
    renderStrategy: Canvas.Cooperative
    // The HTML applies CSS scaleY after drawing. Flipping the finished texture
    // also preserves its antialiasing, rather than rerasterizing mirrored paths.
    transform: Scale {
        origin.y: wave.height / 2
        yScale: wave.vizDirection === "down" && (wave.visualizerType === 1 || wave.visualizerType === 6 || wave.visualizerType === 7 || wave.visualizerType === 8) ? -1 : 1
    }

    // Match the system monitor's chart pipeline: rasterize the geometry once,
    // then blur its combined texture on the GPU. Canvas shadowBlur performs a
    // separate CPU image blur for every stroke, bar and dot in every frame.
    // Qt's software scene graph cannot render MultiEffect; keep the waveform
    // visible there without falling back to those expensive CPU shadows.
    layer.enabled: visualizerType < 6 && glowWave && bloom > 0 && hasAudio && !backendFailed && GraphicsInfo.api !== GraphicsInfo.Software
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: wave._mainColor
        shadowOpacity: 1.0
        shadowBlur: 1.0
        blurMax: 8 * Math.max(0, Math.min(2, wave.bloom))
        autoPaddingEnabled: false
    }

    // A palette change, not an audio frame, creates these colors. In the dot
    // styles this avoids hundreds of QColor conversions per second.
    readonly property color _idleColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.35)
    readonly property color _color35: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.35)
    readonly property color _color38: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.38)
    readonly property color _color02: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.02)
    readonly property color _color95: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.95)
    readonly property color _color92: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.92)
    readonly property color _color55: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.55)
    readonly property color _color00: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.0)
    readonly property color _color100: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 1.0)
    readonly property color _color75: Qt.rgba(_mainColor.r, _mainColor.g, _mainColor.b, 0.75)

    // The cosine taper depends only on the bar count. Preserve the original
    // edge shape without recalculating it for both mirrors and every node.
    readonly property var _tapers: {
        const values = [];
        for (let i = 0; i < _sampleCount; i++) {
            const pos = _sampleCount > 1 ? i / (_sampleCount - 1) : 0.5;
            const edge = 0.15;
            const weight = pos < edge ? pos / edge : (pos > 1.0 - edge ? (1.0 - pos) / edge : 1.0);
            values.push(weight < 1.0 ? 0.5 - 0.5 * Math.cos(weight * Math.PI) : 1.0);
        }
        return values;
    }
    property var _drawCache: ({
            levels: [],
            fillAbove: null,
            fillBelow: null
        })

    function repaint() {
        if (visible)
            requestPaint();
    }

    function invalidateGradients() {
        _drawCache.fillAbove = null;
        _drawCache.fillBelow = null;
        repaint();
    }

    onBarsChanged: {
        if (hasAudio && !backendFailed)
            repaint();
    }
    onHasAudioChanged: repaint()
    onBackendFailedChanged: repaint()
    onWaveColorChanged: invalidateGradients()
    onTextColorChanged: {
        if (!hasAudio)
            repaint();
    }
    onNumBarsChanged: repaint()
    onMaxRangeChanged: repaint()
    onLineWidthChanged: repaint()
    onFillWaveChanged: repaint()
    onGlowWaveChanged: repaint()
    onVisualizerTypeChanged: repaint()
    onVisibleChanged: repaint()
    onWidthChanged: repaint()
    onHeightChanged: invalidateGradients()
    onAvailableChanged: invalidateGradients()
    onColorStopsChanged: invalidateGradients()
    onVizColorModeChanged: repaint()
    onBloomChanged: repaint()
    onRibbonCurvatureChanged: repaint()
    onRibbonFullnessChanged: repaint()
    onReducedMotionChanged: repaint()
    onBassChanged: {
        if (hasAudio && !backendFailed && (visualizerType === 11 || visualizerType === 13 || visualizerType === 15))
            repaint();
    }
    onMidChanged: {
        if (hasAudio && !backendFailed && visualizerType === 15 && !reducedMotion)
            repaint();
    }
    onHighChanged: {
        if (hasAudio && !backendFailed && visualizerType === 15)
            repaint();
    }
    onEnergyChanged: {
        if (hasAudio && !backendFailed && (visualizerType === 11 || visualizerType === 13 || visualizerType === 15))
            repaint();
    }
    onVisualFrameTimeChanged: {
        if (hasAudio && !backendFailed && !reducedMotion && (visualizerType === 9 || visualizerType === 10 || visualizerType === 11 || visualizerType === 13 || visualizerType === 15))
            repaint();
    }
    onPeaksChanged: {
        if (hasAudio && !backendFailed && visualizerType === 6)
            repaint();
    }
    onParticlesChanged: {
        if (hasAudio && !backendFailed && visualizerType === 14)
            repaint();
    }
    onRipplesChanged: {
        if (hasAudio && !backendFailed && visualizerType === 15)
            repaint();
    }

    onEdgeFadeChanged: repaint()

    onPaint: {
        const ctx = getContext("2d");
        paintFrame(ctx);
        // Poster texture: fade both sides like the HTML's CSS mask.
        if (edgeFade) {
            ctx.save();
            ctx.globalCompositeOperation = "destination-in";
            const fade = ctx.createLinearGradient(0, 0, width, 0);
            fade.addColorStop(0, Qt.rgba(0, 0, 0, 0));
            fade.addColorStop(0.14, Qt.rgba(0, 0, 0, 1));
            fade.addColorStop(0.86, Qt.rgba(0, 0, 0, 1));
            fade.addColorStop(1, Qt.rgba(0, 0, 0, 0));
            ctx.fillStyle = fade;
            ctx.fillRect(0, 0, width, height);
            ctx.restore();
        }
    }

    function paintFrame(ctx) {
        ctx.reset();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        const mid = height / 2;
        const n = _sampleCount;
        const vtype = visualizerType;

        // Backend down: the label above carries the explanation,
        // so leave the canvas empty instead of striping the text
        // with the idle line.
        if (backendFailed)
            return;

        // ── Idle line (all visualizer types) ──────────────────
        if (!hasAudio) {
            ctx.lineWidth = 1.2;
            ctx.strokeStyle = _idleColor;
            ctx.beginPath();
            ctx.moveTo(2, mid);
            ctx.lineTo(width - 2, mid);
            ctx.stroke();
            return;
        }

        if (vtype >= 6) {
            WaveDraw.draw(ctx, {
                width: width,
                height: height,
                type: vtype,
                lineWidth: lineWidth,
                levels: WaveMath.levels(bars, n, maxRange),
                stops: colorStops,
                colorMode: vizColorMode,
                hueShifted: hueReactive && !reducedMotion && (Math.sin(visualFrameTime / 1000 * .15) * 20 + (high - .5) * 14) !== 0,
                time: visualFrameTime / 1000,
                reducedMotion: reducedMotion,
                bass: bass,
                mid: wave.mid,
                high: high,
                energy: energy,
                fill: fillWave,
                glow: glowWave,
                bloom: bloom,
                curvature: ribbonCurvature,
                fullness: ribbonFullness,
                peaks: peaks,
                particles: particles,
                ripples: ripples
            });
            return;
        }
        const paint = _colored ? WaveDraw.paintFor(ctx, colorStops, width) : waveColor;

        // Read the QML-backed sample list once and normalize each bar once.
        // Mirrored paths and their dots share these values within this frame.
        const samples = bars;
        const range = maxRange;
        const taper = _tapers;
        const levels = _drawCache.levels;
        for (let i = 0; i < n; i++)
            levels[i] = ((samples[i] || 0) / range) * taper[i];

        // ═════════════════════════════════════════════════════
        // TYPE 0 — Smooth Wave (mirrored bezier)
        // ═════════════════════════════════════════════════════
        if (vtype === 0) {
            const step0 = width / (n - 1);
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = paint;

            if (fillWave && !_drawCache.fillAbove) {
                const amp = height * 0.42;
                const above = ctx.createLinearGradient(0, mid, 0, mid - amp);
                const below = ctx.createLinearGradient(0, mid, 0, mid + amp);
                above.addColorStop(0.0, _color38);
                above.addColorStop(1.0, _color02);
                below.addColorStop(0.0, _color38);
                below.addColorStop(1.0, _color02);
                _drawCache.fillAbove = above;
                _drawCache.fillBelow = below;
            }

            function plot0(sign) {
                ctx.beginPath();
                const amp = height * 0.42;
                let prevX = 0;
                let prevY = mid + sign * levels[0] * amp;
                ctx.moveTo(prevX, prevY);
                for (let i = 1; i < n; i++) {
                    const v = levels[i];
                    const x = i * step0;
                    const y = mid + sign * v * amp;
                    const cpX = (prevX + x) / 2;
                    ctx.bezierCurveTo(cpX, prevY, cpX, y, x, y);
                    prevX = x;
                    prevY = y;
                }
                ctx.stroke();

                if (fillWave) {
                    ctx.lineTo(width, mid);
                    ctx.lineTo(0, mid);
                    ctx.closePath();
                    ctx.fillStyle = sign < 0 ? _drawCache.fillAbove : _drawCache.fillBelow;
                    ctx.fill();
                }
            }
            plot0(-1);
            plot0(1);

            // ═════════════════════════════════════════════════════
            // TYPE 1 — Rounded Bars (upward bars from bottom)
            // ═════════════════════════════════════════════════════
        } else if (vtype === 1) {
            const totalW = width;
            const gap = Math.max(1, totalW / n * 0.25);
            const barW = Math.max(1, totalW / n - gap);
            const r = barW / 2;
            const amp1 = height * 0.88;
            ctx.lineWidth = 0;
            ctx.strokeStyle = "transparent";

            for (let i = 0; i < n; i++) {
                const v = levels[i];
                const bh = Math.max(2, v * amp1);
                const x = i * (barW + gap) + gap / 2;
                const y = height - bh;

                // gradient fill per bar
                const g = ctx.createLinearGradient(0, y, 0, height);
                const barColor = _colored ? WaveDraw.colorAt(colorStops, (x + barW / 2) / width) : waveColor;
                g.addColorStop(0.0, _colored ? WaveDraw.alpha(barColor, .95) : _color95);
                g.addColorStop(1.0, _colored ? WaveDraw.alpha(barColor, .35) : _color35);
                ctx.fillStyle = g;

                // rounded-top rectangle
                ctx.beginPath();
                if (bh > r * 2) {
                    ctx.moveTo(x + r, y);
                    ctx.arc(x + r, y + r, r, Math.PI, 0);
                    ctx.lineTo(x + barW, height);
                    ctx.lineTo(x, height);
                    ctx.closePath();
                } else {
                    ctx.arc(x + r, y + r, r, 0, Math.PI * 2);
                }
                ctx.fill();
            }

            // ═════════════════════════════════════════════════════
            // TYPE 2 — Mirror Bars (bars grow from centre up & down)
            // ═════════════════════════════════════════════════════
        } else if (vtype === 2) {
            const totalW2 = width;
            const gap2 = Math.max(1, totalW2 / n * 0.22);
            const barW2 = Math.max(1, totalW2 / n - gap2);
            const r2 = barW2 / 2;
            const amp2 = height * 0.44;

            for (let i = 0; i < n; i++) {
                const v = levels[i];
                const bh = Math.max(2, v * amp2);
                const x = i * (barW2 + gap2) + gap2 / 2;

                const g2 = ctx.createLinearGradient(0, mid - bh, 0, mid + bh);
                const barColor = _colored ? WaveDraw.colorAt(colorStops, (x + barW2 / 2) / width) : waveColor;
                g2.addColorStop(0.0, _colored ? WaveDraw.alpha(barColor, .35) : _color35);
                g2.addColorStop(0.5, _colored ? WaveDraw.alpha(barColor, .95) : _color95);
                g2.addColorStop(1.0, _colored ? WaveDraw.alpha(barColor, .35) : _color35);
                ctx.fillStyle = g2;

                // top half
                ctx.beginPath();
                if (bh > r2) {
                    ctx.moveTo(x, mid);
                    ctx.lineTo(x, mid - bh + r2);
                    ctx.arc(x + r2, mid - bh + r2, r2, Math.PI, 0);
                    ctx.lineTo(x + barW2, mid);
                    ctx.closePath();
                } else {
                    ctx.arc(x + r2, mid - r2, r2, 0, Math.PI * 2);
                }
                ctx.fill();

                // bottom half
                ctx.beginPath();
                if (bh > r2) {
                    ctx.moveTo(x, mid);
                    ctx.lineTo(x, mid + bh - r2);
                    ctx.arc(x + r2, mid + bh - r2, r2, Math.PI, 2 * Math.PI);
                    ctx.lineTo(x + barW2, mid);
                    ctx.closePath();
                } else {
                    ctx.arc(x + r2, mid + r2, r2, 0, Math.PI * 2);
                }
                ctx.fill();
            }

            // ═════════════════════════════════════════════════════
            // TYPE 3 — Tech Line (stepped segments with node dots)
            // ═════════════════════════════════════════════════════
        } else if (vtype === 3) {
            const step3 = width / (n - 1);
            const amp3 = height * 0.42;
            ctx.lineWidth = lineWidth;
            ctx.strokeStyle = paint;

            function drawTechLine(sign) {
                ctx.beginPath();
                for (let i = 0; i < n; i++) {
                    const v = levels[i];
                    const x = i * step3;
                    const y = mid + sign * v * amp3;
                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        // horizontal then vertical — oscilloscope step look
                        ctx.lineTo(x - step3 * 0.5, mid + sign * levels[i - 1] * amp3);
                        ctx.lineTo(x - step3 * 0.5, y);
                        ctx.lineTo(x, y);
                    }
                }
                ctx.stroke();

                // node dots at each sample
                for (let i = 0; i < n; i++) {
                    const v = levels[i];
                    const x = i * step3;
                    const y = mid + sign * v * amp3;
                    ctx.beginPath();
                    ctx.arc(x, y, 1.6, 0, Math.PI * 2);
                    ctx.fillStyle = paint;
                    ctx.fill();
                }
            }
            drawTechLine(-1);
            drawTechLine(1);

            // ═════════════════════════════════════════════════════
            // TYPE 4 — Floating Dots (soft radial blobs, lineWidth scales size)
            // ═════════════════════════════════════════════════════
        } else if (vtype === 4) {
            const step4 = width / n;
            const amp4 = height * 0.42;
            // lineWidth (1–8) scales how big the dots get
            const maxR = Math.max(2, step4 * 0.28 * (lineWidth / 2.0));

            function drawDot4(cx, cy, dotR, color) {
                // solid bright core so it's always visible
                ctx.beginPath();
                ctx.arc(cx, cy, dotR * 0.45, 0, Math.PI * 2);
                ctx.fillStyle = _colored ? WaveDraw.alpha(color, .92) : _color92;
                ctx.fill();
                // soft glow halo
                const grad = ctx.createRadialGradient(cx, cy, dotR * 0.3, cx, cy, dotR);
                grad.addColorStop(0.0, _colored ? WaveDraw.alpha(color, .55) : _color55);
                grad.addColorStop(1.0, _colored ? WaveDraw.alpha(color, 0) : _color00);
                ctx.beginPath();
                ctx.arc(cx, cy, dotR, 0, Math.PI * 2);
                ctx.fillStyle = grad;
                ctx.fill();
            }

            for (let i = 0; i < n; i++) {
                const v = levels[i];
                const cx = i * step4 + step4 / 2;
                const dotR = Math.max(1.5, v * maxR);

                const dotColor = _colored ? WaveDraw.colorAt(colorStops, cx / width) : waveColor;
                drawDot4(cx, mid - v * amp4, dotR, dotColor);
                drawDot4(cx, mid + v * amp4, dotR, dotColor);
            }

            // ═════════════════════════════════════════════════════
            // TYPE 5 — Floating Dots Bold (outlined rings, high-contrast)
            // ═════════════════════════════════════════════════════
        } else if (vtype === 5) {
            const step5 = width / n;
            const amp5 = height * 0.42;
            const maxR5 = Math.max(2, step5 * 0.32);
            const strokeW = Math.max(0.8, lineWidth * 0.6);

            function drawRing(cx, cy, dotR, color) {
                // filled center (always punchy)
                ctx.beginPath();
                ctx.arc(cx, cy, Math.max(0.8, dotR * 0.38), 0, Math.PI * 2);
                ctx.fillStyle = _colored ? WaveDraw.alpha(color, 1) : _color100;
                ctx.fill();
                // outer ring stroke
                ctx.beginPath();
                ctx.arc(cx, cy, dotR, 0, Math.PI * 2);
                ctx.strokeStyle = _colored ? WaveDraw.alpha(color, .75) : _color75;
                ctx.lineWidth = strokeW;
                ctx.stroke();
            }

            for (let i = 0; i < n; i++) {
                const v = levels[i];
                const cx = i * step5 + step5 / 2;
                const dotR = Math.max(1.5, v * maxR5);

                const dotColor = _colored ? WaveDraw.colorAt(colorStops, cx / width) : waveColor;
                drawRing(cx, mid - v * amp5, dotR, dotColor);
                drawRing(cx, mid + v * amp5, dotR, dotColor);
            }
        }
    }
}
