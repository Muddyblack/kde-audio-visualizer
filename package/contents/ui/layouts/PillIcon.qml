import QtQuick
import ".."

// Panel icon (HTML `.L-pillicon`): the 22 px cover with an EQ badge, or with
// pillEq "wave" an 18 px cover inside a mini orbit ring.
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property string eqMode: view.hasPlayer ? (cfg.pillEq ?? "static") : "off"
    readonly property bool orbit: eqMode === "wave"

    implicitWidth: 30
    implicitHeight: 30

    OrbitView {
        simpleRender: root.cfg.simpleRender ?? false
        objectName: "pillOrbit"
        visible: root.orbit
        anchors.centerIn: parent
        width: 40
        height: 40
        coverRatio: 0.45
        numBars: 14
        bars: root.view.visualizer.bars ?? []
        maxRange: root.view.visualizer.maxRange ?? 1000
        hasAudio: root.view.visualizer.hasAudio ?? false
        backendFailed: root.view.visualizer.backendFailed ?? false
        visualFrameTime: root.view.visualFrameTime
        high: root.view.visualizer.high ?? 0
        waveColor: root.view.waveColor
        coverColor1: root.view.coverColor1
        coverColor2: root.view.coverColor2
        vizColorMode: root.cfg.vizColorMode ?? "solid"
        vizPalette: root.cfg.vizPalette ?? "aurora"
        hueReactive: root.cfg.hueReactive ?? false
        lineWidth: 1
        glowWave: (root.cfg.glowWave ?? true) && !root.view.batterySaving
        bloom: root.cfg.bloom ?? 1
        reducedMotion: root.cfg.reducedMotion ?? false
        orbitStyle: root.cfg.orbitStyle ?? "bars"
        orbitRotate: root.cfg.orbitRotate ?? true
    }

    ArtView {
        id: art
        objectName: "pillIconArt"
        anchors.centerIn: parent
        width: root.orbit ? 18 : 22
        height: width
        view: root.view
        artUrl: root.view.artUrl
        desktopEntry: root.view.desktopEntry
        fallbackIcon: root.view.fallbackIcon

        CoverRing {
            anchors.fill: parent
            anchors.margins: -3
            band: 1.5
            visible: root.cfg.pillProgress === "ring" && root.view.hasPlayer
            player: root.view.player
            isPlaying: root.view.isPlaying
            playbackActive: root.view.visualizer.plasmoidVisible
            track: root.view.track
            positionUnitsPerSecond: root.view.positionUnitsPerSecond
            visualFrameTime: root.view.visualFrameTime
            accentColor: root.view.waveColor
            cornerRadius: art.shape === "circle" || art.disc ? (art.width + 6) / 2 : 13
        }

        // EQ badge in the corner.
        Rectangle {
            visible: !root.orbit && (root.eqMode === "static" || root.eqMode === "live")
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -3
            anchors.bottomMargin: -1
            width: badge.width + 2
            height: 9
            radius: 3
            color: Qt.rgba(0, 0, 0, 0xaa / 255)
            PanelEq {
                id: badge
                anchors.centerIn: parent
                view: root.view
                live: root.eqMode === "live"
                barWidth: 1.5
                barHeight: 7
            }
        }
    }
}
