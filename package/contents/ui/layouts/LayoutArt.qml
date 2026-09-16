import QtQuick
import ".."

// Cover slot shared by the layouts. With progress style 10 the cover shrinks by
// `ringShrink` and the ring sits 4 px outside it, as in the HTML `.artwrap`.
Item {
    id: root
    required property var view
    property real size: 72
    property real ringShrink: 0
    readonly property bool ringMode: (view.configuration.progressBarStyle ?? 0) === 10
    readonly property bool shown: view.configuration.showMpris && view.configuration.showArtThumb && (!view.artIsBackground || view.configuration.artBgKeepThumb)
    readonly property real artSize: Math.max(0, Math.round(size - (ringMode ? ringShrink : 0)))

    visible: shown
    implicitWidth: shown ? artSize : 0
    implicitHeight: implicitWidth

    ArtView {
        id: artView
        anchors.fill: parent
        view: root.view
        artUrl: root.view.artUrl
        desktopEntry: root.view.desktopEntry
        fallbackIcon: root.view.fallbackIcon

        CoverRing {
            objectName: "coverRing"
            anchors.fill: parent
            anchors.margins: -4
            visible: root.ringMode && root.view.hasPlayer
            player: root.view.player
            isPlaying: root.view.isPlaying
            playbackActive: root.view.visualizer.plasmoidVisible
            track: root.view.track
            positionUnitsPerSecond: root.view.positionUnitsPerSecond
            visualFrameTime: root.view.visualFrameTime
            accentColor: root.view.waveColor
            cornerRadius: artView.ringRadius
        }
    }
}
