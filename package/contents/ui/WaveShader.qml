import QtQuick
import "../code/WaveMath.js" as WaveMath

// GPU counterpart of WaveCanvas: the same inputs are drawn by one fragment
// shader, so an audio frame costs a few uniform writes instead of a CPU raster
// pass, a texture upload and MultiEffect blur passes. Waveform.qml keeps
// WaveCanvas for scene graphs that cannot run shaders.
Item {
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
    readonly property real _timeSeconds: !reducedMotion && (visualizerType === 9 || visualizerType === 10 || visualizerType === 11 || visualizerType === 13 || visualizerType === 15) ? visualFrameTime / 1000 : 0
    readonly property bool _usesBass: visualizerType === 11 || visualizerType === 13 || visualizerType === 15
    readonly property var _colors: WaveMath.colorStops(waveColor, vizColorMode, vizPalette, coverColor1, coverColor2, hueReactive, hueReactive && !reducedMotion ? high : 0.5, !reducedMotion && (hueReactive || vizColorMode === "rainbow") ? visualFrameTime / 1000 : 0, reducedMotion)
    readonly property string _shaderFamily: visualizerType <= 5 ? "visualizer" : visualizerType === 11 || visualizerType === 13 ? "viz_radial" : visualizerType === 14 ? "viz_particles" : visualizerType === 15 ? "viz_ribbon" : "viz_linear"
    // Two Gaussians fitted to WaveCanvas' MultiEffect shadow (shadowBlur 1,
    // blurMax 8): line, edge, dot and translucent-fill profiles.
    property real glowSigma: 2.136
    property real glowGain: 0.533
    property real glowSigma2: 5.875
    property real glowGain2: 0.091

    // The shader holds 32 vec4 blocks; settings allow at most 128 bars.
    readonly property int _count: WaveMath.count(numBars, width, visualizerType)
    readonly property bool _drawing: visible && hasAudio && !backendFailed && width > 0 && height > 0
    readonly property var _blockNames: Array.from({
        length: 32
    }, (_, index) => "levels" + index)

    // The same cosine edge taper WaveCanvas applies.
    readonly property var _tapers: {
        const values = [];
        for (let i = 0; i < _count; i++) {
            const pos = _count > 1 ? i / (_count - 1) : 0.5;
            const edge = 0.15;
            const weight = pos < edge ? pos / edge : (pos > 1.0 - edge ? (1.0 - pos) / edge : 1.0);
            values.push(weight < 1.0 ? 0.5 - 0.5 * Math.cos(weight * Math.PI) : 1.0);
        }
        return values;
    }

    // Hidden, idle and failed states skip uploads; becoming visible uploads
    // the latest frame.
    function upload() {
        if (!_drawing)
            return;
        const n = _count;
        const samples = bars;
        const range = maxRange;
        const taper = _tapers;
        const level = i => i < n && range > 0 ? (samples[i] || 0) / range * taper[i] : 0;
        for (let block = 0; block * 4 < n; block++) {
            const i = block * 4;
            effect[_blockNames[block]] = Qt.vector4d(level(i), level(i + 1), level(i + 2), level(i + 3));
        }
        effect.barCount = n;
    }

    function uploadState() {
        if (!_drawing || visualizerType < 6)
            return;
        if (visualizerType === 6) {
            for (let block = 0; block * 4 < _count; block++) {
                const i = block * 4;
                effect["peaks" + block] = Qt.vector4d(peaks[i] || 0, peaks[i + 1] || 0, peaks[i + 2] || 0, peaks[i + 3] || 0);
            }
        }
        const count = reducedMotion || visualizerType !== 14 ? 0 : Math.min(32, particles.length);
        for (let i = 0; i < count; i++) {
            const p = particles[i];
            effect["particle" + i] = Qt.vector4d(p.x, p.y, p.r, p.life);
        }
        effect.particleCount = count;
        const rings = reducedMotion || visualizerType !== 15 ? 0 : Math.min(4, ripples.length);
        for (let i = 0; i < rings; i++)
            effect["ripple" + i] = Qt.vector4d(ripples[i].x, ripples[i].age, 0, 0);
        effect.rippleCount = rings;
    }

    onPeaksChanged: {
        if (visualizerType === 6)
            uploadState();
    }
    onParticlesChanged: {
        if (visualizerType === 14)
            uploadState();
    }
    onRipplesChanged: {
        if (visualizerType === 15)
            uploadState();
    }
    onReducedMotionChanged: uploadState()
    onVisualizerTypeChanged: uploadState()
    onBarsChanged: upload()
    on_DrawingChanged: {
        upload();
        uploadState();
    }
    on_TapersChanged: {
        upload();
        uploadState();
    }
    onMaxRangeChanged: upload()

    Rectangle {
        // WaveCanvas' idle state: a 1.2 px round-capped centre line.
        objectName: "idleLine"
        visible: !wave.hasAudio && !wave.backendFailed
        x: 1.4
        y: wave.height / 2 - 0.6
        width: Math.max(0, wave.width - 2.8)
        height: 1.2
        radius: 0.6
        antialiasing: true
        color: Qt.rgba(wave.textColor.r, wave.textColor.g, wave.textColor.b, 0.35)
    }

    ShaderEffect {
        id: effect
        objectName: "waveEffect"
        anchors.fill: parent
        visible: wave._drawing
        fragmentShader: Qt.resolvedUrl("../shaders/" + wave._shaderFamily + ".frag.qsb")

        // Uniforms, matched to the shader by name.
        readonly property size canvasSize: Qt.size(width, height)
        readonly property real pixelRatio: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
        readonly property real style: wave.visualizerType
        property real barCount: 0
        readonly property real lineWidth: wave.lineWidth
        readonly property real fillAmount: wave.fillWave ? 1 : 0
        readonly property real glowAmount: wave.glowWave && wave.bloom > 0 ? 1 : 0
        readonly property real glowSigma: wave.glowSigma * Math.max(0.01, wave.bloom)
        readonly property real glowGain: wave.glowGain
        readonly property real glowSigma2: wave.glowSigma2 * Math.max(0.01, wave.bloom)
        readonly property real glowGain2: wave.glowGain2
        readonly property color waveColor: wave.waveColor
        readonly property real timeSeconds: wave._timeSeconds
        readonly property real bass: wave._usesBass ? wave.bass : 0
        readonly property real mid: wave.visualizerType === 15 && !wave.reducedMotion ? wave.mid : 0
        readonly property real high: wave.visualizerType === 15 ? wave.high : 0
        readonly property real energy: wave._usesBass ? wave.energy : 1
        readonly property real reducedMotion: wave.reducedMotion ? 1 : 0
        readonly property real directionDown: wave.vizDirection === "down" ? 1 : 0
        readonly property real solidMode: wave.vizColorMode === "solid" ? 1 : 0
        readonly property real opaqueOrb: wave.visualizerType === 13 && (wave.vizColorMode === "rainbow" || (wave.hueReactive && !wave.reducedMotion && Math.sin(wave.visualFrameTime / 1000 * 0.15) * 20 + (wave.high - 0.5) * 14 !== 0)) ? 1 : 0
        readonly property real colorCount: wave._colors.length
        readonly property real bloom: wave.bloom
        readonly property real ribbonCurvature: wave.ribbonCurvature
        readonly property real ribbonFullness: wave.ribbonFullness
        readonly property real edgeFade: wave.edgeFade ? 1 : 0
        property real particleCount: 0
        property real rippleCount: 0
        readonly property color color0: wave._colors[Math.min(0, wave._colors.length - 1)]
        readonly property color color1: wave._colors[Math.min(1, wave._colors.length - 1)]
        readonly property color color2: wave._colors[Math.min(2, wave._colors.length - 1)]
        readonly property color color3: wave._colors[Math.min(3, wave._colors.length - 1)]
        readonly property color color4: wave._colors[Math.min(4, wave._colors.length - 1)]
        readonly property color color5: wave._colors[Math.min(5, wave._colors.length - 1)]
        property vector4d peaks0
        property vector4d peaks1
        property vector4d peaks2
        property vector4d peaks3
        property vector4d peaks4
        property vector4d peaks5
        property vector4d peaks6
        property vector4d peaks7
        property vector4d peaks8
        property vector4d peaks9
        property vector4d peaks10
        property vector4d peaks11
        property vector4d peaks12
        property vector4d peaks13
        property vector4d peaks14
        property vector4d peaks15
        property vector4d peaks16
        property vector4d peaks17
        property vector4d peaks18
        property vector4d peaks19
        property vector4d peaks20
        property vector4d peaks21
        property vector4d peaks22
        property vector4d peaks23
        property vector4d peaks24
        property vector4d peaks25
        property vector4d peaks26
        property vector4d peaks27
        property vector4d peaks28
        property vector4d peaks29
        property vector4d peaks30
        property vector4d peaks31
        property vector4d particle0
        property vector4d particle1
        property vector4d particle2
        property vector4d particle3
        property vector4d particle4
        property vector4d particle5
        property vector4d particle6
        property vector4d particle7
        property vector4d particle8
        property vector4d particle9
        property vector4d particle10
        property vector4d particle11
        property vector4d particle12
        property vector4d particle13
        property vector4d particle14
        property vector4d particle15
        property vector4d particle16
        property vector4d particle17
        property vector4d particle18
        property vector4d particle19
        property vector4d particle20
        property vector4d particle21
        property vector4d particle22
        property vector4d particle23
        property vector4d particle24
        property vector4d particle25
        property vector4d particle26
        property vector4d particle27
        property vector4d particle28
        property vector4d particle29
        property vector4d particle30
        property vector4d particle31
        property vector4d ripple0
        property vector4d ripple1
        property vector4d ripple2
        property vector4d ripple3
        property vector4d levels0
        property vector4d levels1
        property vector4d levels2
        property vector4d levels3
        property vector4d levels4
        property vector4d levels5
        property vector4d levels6
        property vector4d levels7
        property vector4d levels8
        property vector4d levels9
        property vector4d levels10
        property vector4d levels11
        property vector4d levels12
        property vector4d levels13
        property vector4d levels14
        property vector4d levels15
        property vector4d levels16
        property vector4d levels17
        property vector4d levels18
        property vector4d levels19
        property vector4d levels20
        property vector4d levels21
        property vector4d levels22
        property vector4d levels23
        property vector4d levels24
        property vector4d levels25
        property vector4d levels26
        property vector4d levels27
        property vector4d levels28
        property vector4d levels29
        property vector4d levels30
        property vector4d levels31
    }
}
