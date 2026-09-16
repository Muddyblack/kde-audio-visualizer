import QtQuick
import "../code/WaveMath.js" as WaveMath
import "../code/OrbitDraw.js" as OrbitDraw

// Orbit layout ring: the visualizer drawn in polar coordinates around the
// cover. Decorative motion (rotation, ribbon wobble, sparks) rides audio
// frames; sparks are capped at 32 and advance once per audio timestamp.
Item {
    id: orbit
    property bool shaderEnabled: false

    property var bars: []
    property real maxRange: 1000
    property int numBars: 24
    property bool hasAudio: false
    property bool backendFailed: false
    property real visualFrameTime: 0
    property real high: 0
    property color waveColor: "#ffffff"
    property color coverColor1: waveColor
    property color coverColor2: waveColor
    property string vizColorMode: "solid"
    property string vizPalette: "aurora"
    property bool hueReactive: false
    property real lineWidth: 1.8
    property bool fillWave: false
    property bool glowWave: true
    property real bloom: 1
    property bool reducedMotion: false
    property string orbitStyle: "bars"
    property real orbitReach: 1
    property bool orbitRotate: true
    // (cover + ring allowance) / box, as the HTML's data-r.
    property real coverRatio: 0.38
    property var particles: []
    property real _lastFrame: -1
    property int _seed: 1

    readonly property int half: Math.max(12, Math.min(48, numBars))
    readonly property real seconds: visualFrameTime / 1000
    readonly property real ringRotation: orbitRotate && !reducedMotion ? (seconds * 0.2) % (Math.PI * 2) : 0
    readonly property bool sparks: orbitStyle === "sparks" && !reducedMotion
    readonly property bool drawing: visible && hasAudio && !backendFailed
    readonly property var colorStops: WaveMath.colorStops(waveColor, vizColorMode, vizPalette, coverColor1, coverColor2, hueReactive, hueReactive && !reducedMotion ? high : 0.5, !reducedMotion && (hueReactive || vizColorMode === "rainbow") ? seconds : 0, reducedMotion)

    function values() {
        const out = [];
        const count = bars.length;
        for (let i = 0; i < half; i++) {
            const index = count > 1 ? Math.round(i * (count - 1) / (half - 1)) : 0;
            out.push(drawing && maxRange > 0 ? Math.min(1, (bars[index] || 0) / maxRange) : 0);
        }
        return out;
    }

    function geometry() {
        const radius = Math.min(width, height) / 2;
        const inner = radius * coverRatio + 4;
        return {
            radius: radius,
            inner: inner,
            reach: Math.max(2, (radius - inner - 2) * 1.3 * orbitReach)
        };
    }

    function random() {
        _seed = (Math.imul(_seed, 1664525) + 1013904223) | 0;
        return (_seed >>> 0) / 4294967296;
    }

    function advance() {
        if (!sparks || !drawing) {
            if (particles.length)
                particles = [];
            _lastFrame = -1;
            return;
        }
        if (visualFrameTime === _lastFrame)
            return;
        // The HTML advances at 60 Hz; scale to elapsed audio time.
        const step = _lastFrame < 0 ? 1 : Math.max(0, Math.min(6, (visualFrameTime - _lastFrame) * 0.06));
        _lastFrame = visualFrameTime;
        const g = geometry(), v = values(), n = half * 2, next = [];
        for (const p of particles) {
            const life = p.life - 0.02 * step, r = p.r + p.v * step;
            if (life > 0 && r < g.radius)
                next.push({
                    a: p.a,
                    r: r,
                    v: p.v,
                    life: life,
                    s: p.s
                });
        }
        // Start at a random spoke so the cap does not favour one side.
        const start = Math.floor(random() * n);
        for (let k = 0; k < n && next.length < 32; k++) {
            const j = (start + k) % n, level = v[j < half ? j : n - 1 - j];
            if (random() < 1 - Math.pow(1 - level * 0.12, step))
                next.push({
                    a: j / n * Math.PI * 2 + ringRotation - Math.PI / 2 + (random() - 0.5) * 0.1,
                    r: g.inner + 3,
                    v: (0.4 + random()) * (1 + level),
                    life: 1,
                    s: 0.6 + random() * 1.3
                });
        }
        if (particles.length || next.length)
            particles = next;
    }

    function repaint() {
        if (visible && painter.item)
            painter.item.requestPaint();
    }

    onVisualFrameTimeChanged: {
        advance();
        if (drawing && (ringRotation !== 0 || orbitStyle === "ribbon" || sparks))
            repaint();
    }
    onBarsChanged: {
        if (drawing)
            repaint();
    }
    onSparksChanged: advance()
    onDrawingChanged: {
        advance();
        repaint();
    }
    onParticlesChanged: repaint()
    onMaxRangeChanged: repaint()
    onHalfChanged: repaint()
    onWidthChanged: repaint()
    onHeightChanged: repaint()
    onOrbitStyleChanged: repaint()
    onOrbitReachChanged: repaint()
    onCoverRatioChanged: repaint()
    onColorStopsChanged: repaint()
    onLineWidthChanged: repaint()
    onFillWaveChanged: repaint()
    onGlowWaveChanged: repaint()
    onBloomChanged: repaint()

    Loader {
        id: painter
        anchors.fill: parent
        active: !orbit.shaderEnabled
        sourceComponent: Canvas {
            antialiasing: true
            renderStrategy: Canvas.Cooperative
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (orbit.backendFailed)
                    return;
                const g = orbit.geometry();
                OrbitDraw.draw(ctx, {
                    width: width,
                    height: height,
                    R: g.inner,
                    reach: g.reach,
                    style: orbit.orbitStyle,
                    values: orbit.values(),
                    rot: orbit.ringRotation,
                    t: orbit.reducedMotion ? 0 : orbit.seconds,
                    stops: orbit.colorStops,
                    lineWidth: orbit.lineWidth,
                    fill: orbit.fillWave,
                    glow: orbit.glowWave ? Math.max(0, Math.min(2, orbit.bloom)) : 0,
                    particles: orbit.particles
                });
            }
        }
    }
}
