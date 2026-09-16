pragma ComponentBehavior: Bound
import QtQuick

// Picks the waveform renderer for the scene graph in use: WaveShader wherever
// shaders run, WaveCanvas on the software renderer (which ignores ShaderEffect).
Item {
    id: root

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
    property bool attack: false
    property real energy: hasAudio ? 1 : 0
    property bool reducedMotion: false
    property bool simpleRender: false
    property string vizDirection: "up"
    property string vizColorMode: "solid"
    property string vizPalette: "aurora"
    property bool hueReactive: false
    property real bloom: 1
    property real ribbonCurvature: 1
    property real ribbonFullness: 1
    property color coverColor1: waveColor
    property color coverColor2: waveColor
    // Fades both sides; the poster layout uses the wave as a texture.
    property bool edgeFade: false
    readonly property var peaks: motion.peaks
    readonly property var particles: motion.particles
    readonly property var ripples: motion.ripples

    WaveMotion {
        id: motion
        objectName: "waveMotion"
        active: root.visible && root.hasAudio && !root.backendFailed && (root.visualizerType === 6 || (!root.reducedMotion && (root.visualizerType === 14 || root.visualizerType === 15)))
        style: root.visualizerType
        frameTime: root.visualFrameTime
        bars: root.bars
        numBars: root.numBars
        maxRange: root.maxRange
        width: root.width
        height: root.height
        lineWidth: root.lineWidth
        attack: root.attack
        energy: root.energy
        reducedMotion: root.reducedMotion
    }

    // Unknown until the window's scene graph starts; assume shaders until then.
    readonly property bool shaderSupported: !simpleRender && GraphicsInfo.api !== GraphicsInfo.Software

    Loader {
        id: shaderLoader
        objectName: "shaderLoader"
        anchors.fill: parent
        active: root.shaderSupported
        sourceComponent: WaveShader {
            bars: root.bars
            numBars: root.numBars
            maxRange: root.maxRange
            hasAudio: root.hasAudio
            backendFailed: root.backendFailed
            waveColor: root.waveColor
            textColor: root.textColor
            lineWidth: root.lineWidth
            fillWave: root.fillWave
            glowWave: root.glowWave
            visualizerType: root.visualizerType
            visualFrameTime: root.visualFrameTime
            bass: root.bass
            mid: root.mid
            high: root.high
            energy: root.energy
            reducedMotion: root.reducedMotion
            vizDirection: root.vizDirection
            vizColorMode: root.vizColorMode
            vizPalette: root.vizPalette
            hueReactive: root.hueReactive
            bloom: root.bloom
            ribbonCurvature: root.ribbonCurvature
            ribbonFullness: root.ribbonFullness
            coverColor1: root.coverColor1
            coverColor2: root.coverColor2
            peaks: root.peaks
            particles: root.particles
            ripples: root.ripples
            edgeFade: root.edgeFade
        }
    }

    Loader {
        id: canvasLoader
        objectName: "canvasLoader"
        anchors.fill: parent
        active: !root.shaderSupported
        sourceComponent: WaveCanvas {
            bars: root.bars
            numBars: root.numBars
            maxRange: root.maxRange
            hasAudio: root.hasAudio
            backendFailed: root.backendFailed
            waveColor: root.waveColor
            textColor: root.textColor
            lineWidth: root.lineWidth
            fillWave: root.fillWave
            glowWave: root.glowWave
            visualizerType: root.visualizerType
            visualFrameTime: root.visualFrameTime
            bass: root.bass
            mid: root.mid
            high: root.high
            energy: root.energy
            reducedMotion: root.reducedMotion
            vizDirection: root.vizDirection
            vizColorMode: root.vizColorMode
            vizPalette: root.vizPalette
            hueReactive: root.hueReactive
            bloom: root.bloom
            ribbonCurvature: root.ribbonCurvature
            ribbonFullness: root.ribbonFullness
            coverColor1: root.coverColor1
            coverColor2: root.coverColor2
            peaks: root.peaks
            particles: root.particles
            ripples: root.ripples
            edgeFade: root.edgeFade
        }
    }
}
