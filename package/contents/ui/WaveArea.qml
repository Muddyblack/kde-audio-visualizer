import QtQuick
import QtQuick.Controls as QQC

// Backend status and both renderers share the same area in every layout.
Waveform {
    id: root
    required property var configuration
    required property var visualizer
    property string defaultFontFamily: Qt.application.font.family
    // Set by the layout: fade while paused, battery saver, idle ambient wave.
    property bool faded: false
    property bool batterySaving: false
    property bool ambient: false
    // The ambient wave has no audio frames to ride; it updates at the capped
    // frame rate (at most 20 Hz) only while enabled and nothing plays.
    property real _ambientTime: 0
    Timer {
        interval: Math.round(1000 / Math.max(1, Math.min(20, root.configuration.framerate ?? 30)))
        running: root.ambient && root.visible && !root.backendFailed && !root.reducedMotion && !root.batterySaving
        repeat: true
        onTriggered: root._ambientTime = Date.now()
    }
    readonly property var ambientBars: {
        const count = Math.max(8, root.visualizer?.numBars ?? 24), range = root.visualizer?.maxRange ?? 1000;
        const t = _ambientTime / 1000 * 0.35;
        const out = [];
        for (let i = 0; i < count; i++)
            out.push(range * 0.22 * (0.55 + 0.45 * Math.sin(t * 1.3 + i * 0.45)) * (0.6 + 0.4 * Math.sin(t * 0.7 + i * 0.21)));
        return out;
    }

    opacity: faded ? 0.28 : 1
    Behavior on opacity {
        NumberAnimation {
            duration: 400
        }
    }

    bars: ambient ? ambientBars : (root.visualizer?.bars ?? [])
    numBars: ambient ? ambientBars.length : (root.visualizer?.numBars ?? 0)
    maxRange: root.visualizer?.maxRange ?? 1000
    hasAudio: ambient || (root.visualizer?.hasAudio ?? false)
    backendFailed: root.visualizer?.backendFailed ?? false
    lineWidth: root.configuration.lineWidth
    fillWave: root.configuration.fillWave
    glowWave: root.configuration.glowWave && !batterySaving
    visualizerType: root.configuration.visualizerType
    visualFrameTime: ambient ? _ambientTime : (root.visualizer?.frameTimeMs ?? 0)
    bass: root.visualizer?.bass ?? 0
    mid: root.visualizer?.mid ?? 0
    high: root.visualizer?.high ?? 0
    attack: root.visualizer?.attack ?? false
    reducedMotion: root.configuration.reducedMotion ?? false
    simpleRender: root.configuration.simpleRender ?? false
    vizDirection: root.configuration.vizDirection ?? "up"
    vizColorMode: root.configuration.vizColorMode ?? "solid"
    vizPalette: root.configuration.vizPalette ?? "aurora"
    hueReactive: root.configuration.hueReactive ?? false
    bloom: root.configuration.bloom ?? 1
    ribbonCurvature: root.configuration.ribbonCurvature ?? 1
    ribbonFullness: root.configuration.ribbonFullness ?? 1

    // Backend down: say what broke and what to type, instead of
    // drawing a flat line that looks exactly like silence.
    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 0
        visible: root.backendFailed

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: 10
            color: root.textColor
            opacity: 0.8
            text: root.visualizer?.backendMessage ?? ""
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            // Monospace only when the line is literally a
            // command to type.
            font.family: root.visualizer?.backendCode === "no-cava" ? "monospace" : root.defaultFontFamily
            font.pixelSize: 9
            color: root.textColor
            opacity: 0.55
            text: root.visualizer?.backendAction ?? ""
            visible: text !== ""
        }

        QQC.ToolTip.visible: hoverHandler.hovered
        QQC.ToolTip.text: (root.visualizer?.backendMessage ?? "") + "\n" + (root.visualizer?.backendHint ?? "")
        HoverHandler {
            id: hoverHandler
        }
    }
}
