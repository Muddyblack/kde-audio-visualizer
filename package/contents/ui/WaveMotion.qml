import QtQuick
import "../code/WaveMath.js" as WaveMath

// Bounded state shared by the GPU and software renderers. Nothing here owns a
// timer: one audio timestamp advances peaks, particles and ripples exactly once.
QtObject {
    id: motion
    property bool active: false
    property bool reducedMotion: false
    property int style: 0
    property real frameTime: 0
    property var bars: []
    property int numBars: 24
    property real maxRange: 1000
    property real width: 0
    property real height: 0
    property real lineWidth: 1.8
    property bool attack: false
    property real energy: 1
    property int randomSeed: 1
    property var peaks: []
    property var particles: []
    property var ripples: []
    property real _lastFrame: -1
    property int _seed: randomSeed
    property bool _destroying: false
    Component.onDestruction: _destroying = true

    function random() {
        _seed = (Math.imul(_seed, 1664525) + 1013904223) | 0;
        return (_seed >>> 0) / 4294967296;
    }

    function reset() {
        if (peaks.length)
            peaks = [];
        if (particles.length)
            particles = [];
        if (ripples.length)
            ripples = [];
        _lastFrame = -1;
        _seed = randomSeed;
    }

    function advance() {
        if (_destroying || !active || frameTime === _lastFrame || width <= 0 || height <= 0)
            return;
        // The HTML preview advances at 60 Hz. Scale decay/movement to elapsed
        // audio time so a 15 Hz widget keeps the same motion speed.
        const step = _lastFrame < 0 ? 1 : Math.max(0, Math.min(6, (frameTime - _lastFrame) * 0.06));
        _lastFrame = frameTime;
        const n = WaveMath.count(numBars, width, style);
        const levels = WaveMath.levels(bars, n, maxRange);
        if (style === 6) {
            peaks = levels.map((value, i) => Math.max(value, (peaks[i] || 0) - 0.01 * step));
        } else if (style === 14 && !reducedMotion) {
            const next = [];
            const slot = width / n;
            for (const p of particles) {
                const life = p.life - 0.025 * step;
                if (life > 0)
                    next.push({
                        x: p.x,
                        y: p.y + p.vy * step,
                        vy: p.vy,
                        r: p.r,
                        life: life
                    });
            }
            for (let i = 0; i < n && next.length < 32; i++) {
                if (random() < 1 - Math.pow(1 - levels[i] * 0.22, step)) {
                    const x = (i + 0.5) * slot + (random() - 0.5) * slot;
                    const y = height / 2 + (random() - 0.5) * levels[i] * height;
                    const vy = -(0.2 + random() * 0.8) * (1 + levels[i]);
                    const r = 0.6 + random() * 1.4 * (lineWidth / 1.8);
                    next.push({
                        x: x,
                        y: y + vy * step,
                        vy: vy,
                        r: r,
                        life: Math.max(0, 1 - 0.025 * step)
                    });
                }
            }
            if (particles.length || next.length)
                particles = next;
        } else if (style === 15 && !reducedMotion) {
            const next = [];
            for (const ripple of ripples) {
                const age = ripple.age + 0.03 * step;
                if (age < 1)
                    next.push({
                        x: ripple.x,
                        age: age
                    });
            }
            // Real analysis already emits a single onset pulse, so unlike the
            // HTML's synthetic held beat no random suppression is necessary.
            if (attack && energy > 0.5 && next.length < 4)
                next.push({
                    x: random() * width,
                    age: 0.03 * step
                });
            if (ripples.length || next.length)
                ripples = next;
        }
    }

    onFrameTimeChanged: advance()
    onStyleChanged: reset()
    onRandomSeedChanged: reset()
    onNumBarsChanged: reset()
    onWidthChanged: reset()
    onHeightChanged: reset()
    onReducedMotionChanged: reset()
    onActiveChanged: {
        reset();
        if (active)
            // bars/hasAudio are published before the timestamp. Let the whole
            // audio frame arrive so waking cannot advance twice at stale time.
            Qt.callLater(advance);
    }
}
