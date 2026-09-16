import QtQuick
import QtQuick.Layouts
import ".."

// Geometry belongs to the layout; rendering and interaction live in shared parts.
Item {
    id: root
    required property var view
    // Mirrored puts the cover column on the right.
    property bool mirrored: false
    implicitWidth: view.configuration.showMpris ? 360 : 200
    implicitHeight: view.configuration.showMpris ? 104 : 84
    // Progress style 10 draws a ring around the cover instead of a bar; the
    // cover shrinks by the ring's 6 px, and without a cover style 0 is used.
    readonly property bool ringMode: (view.configuration.progressBarStyle ?? 0) === 10
    // The HTML's scaled(72, available height); unchanged at the default 100 %.
    readonly property real artLimit: Math.min(ringMode ? Math.min(72, height - (view.configuration.showBg ? 4 : 0) - (view.hasPlayer ? 30 : 0)) : 72, 72 * (view.configuration.artScale ?? 100) / 100) - (ringMode ? 6 : 0)

    RowLayout {
        anchors.fill: parent
        layoutDirection: root.mirrored ? Qt.RightToLeft : Qt.LeftToRight
        anchors.leftMargin: root.view.configuration.showBg ? 10 : 0
        anchors.rightMargin: root.view.configuration.showBg ? 10 : 0
        anchors.topMargin: root.view.configuration.showBg ? 4 : 0
        anchors.bottomMargin: 0
        spacing: root.view.configuration.showMpris ? 12 : 0

        ColumnLayout {
            spacing: 4
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            visible: root.view.configuration.showMpris

            // With no thumbnail, position the dock over the lower card scrim.
            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 1
                visible: !artBox.visible
            }

            ArtView {
                id: artBox
                objectName: "classicArt"
                visible: root.view.configuration.showArtThumb && (!root.view.artIsBackground || root.view.configuration.artBgKeepThumb)
                Layout.fillHeight: true
                Layout.maximumHeight: root.artLimit
                Layout.preferredWidth: visible ? Math.min(artBox.height, root.artLimit) : 0
                Layout.maximumWidth: root.artLimit
                Layout.alignment: Qt.AlignHCenter
                width: Math.min(height, root.artLimit)
                artUrl: root.view.configuration.showMpris ? root.view.artUrl : ""
                desktopEntry: root.view.desktopEntry
                fallbackIcon: root.view.fallbackIcon
                view: root.view

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
                    cornerRadius: artBox.ringRadius
                }
            }

            TransportDock {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: 26
                visible: root.view.hasPlayer
                configuration: root.view.configuration
                player: root.view.player
                isPlaying: root.view.isPlaying
                controlColor: root.view.controlColor
                accentColor: root.view.waveColor
                cardHovered: root.view.cardHovered
            }

            Item {
                Layout.fillHeight: true
                Layout.preferredHeight: 1
                Layout.maximumHeight: 10
                visible: !artBox.visible
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            WaveArea {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.maximumHeight: 44
                configuration: root.view.configuration
                visualizer: root.view.visualizer
                waveColor: root.view.waveColor
                textColor: root.view.textColor
                defaultFontFamily: root.view.defaultFontFamily
                coverColor1: root.view.coverColor1
                coverColor2: root.view.coverColor2
                faded: (root.view.configuration.fadeVizWhenPaused ?? false) && root.view.pausedPlayer
                batterySaving: root.view.batterySaving
                ambient: (root.view.configuration.idleAmbient ?? false) && !root.view.hasPlayer && !(root.view.visualizer.hasAudio ?? false)
            }

            ProgressBar {
                objectName: "progressBar"
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                Layout.topMargin: 1
                Layout.bottomMargin: 1
                player: root.view.player
                isPlaying: root.view.isPlaying
                hasAudio: root.view.visualizer.hasAudio
                playbackActive: root.view.visualizer.plasmoidVisible
                style: root.ringMode && !artBox.visible ? 0 : (root.view.configuration.progressBarStyle ?? 0)
                suppressed: root.ringMode && artBox.visible
                showTimes: root.view.configuration.showTimes ?? true
                timeFormat: root.view.configuration.timeFormat ?? "total"
                centerTimes: root.view.configuration.textAlign === "center"
                reducedMotion: root.view.configuration.reducedMotion ?? false
                track: root.view.track
                artist: root.view.artist
                textColor: root.view.textColor
                waveColor: root.view.waveColor
                controlColor: root.view.controlColor
                pgStartColor: root.view.pgStartColor
                pgEndColor: root.view.pgEndColor
                positionUnitsPerSecond: root.view.positionUnitsPerSecond
                visualFrameTime: root.view.visualFrameTime
            }

            LayoutTexts {
                Layout.fillWidth: true
                view: root.view
            }
        }
    }
}
