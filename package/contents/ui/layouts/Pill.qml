import QtQuick
import QtQuick.Layouts
import ".."

// Panel pill (HTML `.L-pill`): [cover 20][EQ][Title · Artist][controls], 30 px
// high, width following the content up to pillMaxWidth. The underline progress
// sits 2 px above the bottom edge.
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property string eqMode: view.hasPlayer ? (cfg.pillEq ?? "static") : "off"
    readonly property string controls: view.hasPlayer ? (cfg.pillControls ?? "none") : "none"
    readonly property string content: cfg.pillContent ?? "title-artist"
    readonly property string titleText: view.displayTrack !== "" ? view.displayTrack : qsTr("No media")
    readonly property bool withArtist: content !== "title" && view.artist !== ""
    readonly property real maxWidth: cfg.pillMaxWidth ?? 300

    implicitHeight: 30
    implicitWidth: Math.min(maxWidth, row.implicitWidth + 15)

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 10
        spacing: 8

        ArtView {
            objectName: "pillArt"
            visible: root.cfg.pillArt ?? true
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            view: root.view
            roundedRadius: 6
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
                cornerRadius: parent.shape === "circle" || parent.disc ? (parent.width + 6) / 2 : 9
            }
        }

        PanelEq {
            objectName: "pillEq"
            visible: root.eqMode === "static" || root.eqMode === "live"
            live: root.eqMode === "live"
            view: root.view
            Layout.alignment: Qt.AlignVCenter
        }

        LayoutWave {
            objectName: "pillWave"
            visible: root.eqMode === "wave"
            view: root.view
            Layout.preferredWidth: 64
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 5
            Text {
                renderType: Text.CurveRendering ?? Text.QtRendering
                objectName: "pillPrimary"
                Layout.fillWidth: !root.withArtist
                Layout.maximumWidth: implicitWidth
                Layout.minimumWidth: Math.min(implicitWidth, 40)
                text: root.content === "artist-title" && root.withArtist ? root.view.artist : root.titleText
                color: root.view.textColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.italic: root.view.trackUnknown
                elide: Text.ElideRight
            }
            Text {
                renderType: Text.CurveRendering ?? Text.QtRendering
                visible: root.withArtist
                text: root.content === "artist-title" ? "—" : "·"
                color: root.view.textColor
                opacity: 0.35
                font.pixelSize: 12
            }
            Text {
                renderType: Text.CurveRendering ?? Text.QtRendering
                objectName: "pillSecondary"
                visible: root.withArtist
                Layout.fillWidth: true
                Layout.maximumWidth: implicitWidth
                text: root.content === "artist-title" ? root.titleText : root.view.artist
                color: root.view.textColor
                opacity: 0.6
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Row {
            visible: root.controls !== "none"
            Layout.leftMargin: 2
            Layout.alignment: Qt.AlignVCenter
            PillButton {
                visible: root.controls === "all"
                icon: "prev"
                areaName: "pillPrevArea"
                color: root.view.controlColor
                onClicked: root.view.previousTrack()
            }
            PillButton {
                icon: root.view.isPlaying ? "pause" : "play"
                areaName: "pillPlayArea"
                color: root.view.controlColor
                onClicked: root.view.togglePlayback()
            }
            PillButton {
                visible: root.controls === "all"
                icon: "next"
                areaName: "pillNextArea"
                color: root.view.controlColor
                onClicked: root.view.nextTrack()
            }
        }
    }

    // Underline progress (HTML `.pline`).
    Rectangle {
        objectName: "pillUnderline"
        visible: root.cfg.pillProgress === "underline" && root.view.hasPlayer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.bottomMargin: 2
        height: 2
        radius: 2
        color: Qt.rgba(1, 1, 1, 0x1f / 255)
        clip: true
        PlaybackClock {
            id: underlineClock
            unitScale: root.view.positionUnitsPerSecond
            updateInterval: 1000
            player: root.view.player
            playing: root.view.isPlaying
            track: root.view.track
            active: parent.visible && root.view.visualizer.plasmoidVisible
        }
        Connections {
            target: root.view
            function onVisualFrameTimeChanged() {
                if (underlineClock.active && root.view.isPlaying)
                    underlineClock.tick();
            }
        }
        Rectangle {
            height: parent.height
            // A new width only when the fill reaches another pixel.
            width: Math.round(parent.width * underlineClock.progress)
            color: root.view.waveColor
        }
    }
}
