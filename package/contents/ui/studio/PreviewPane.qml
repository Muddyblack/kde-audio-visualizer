import QtQuick
import QtQuick.Controls.Basic as Controls
import ".."
import "Theme.js" as Theme
import "Schema.js" as Schema
import "../../code/Layouts.js" as LayoutSizes

// The live preview (HTML `.stage`): wallpaper, state and zoom chips, the real
// widget with the draft settings and synthetic audio; pills sit in a panel.
Rectangle {
    id: pane
    required property var studio
    property string backdrop: "dusk"
    property string stateName: "normal"
    property string zoom: "fit"
    property bool compact: false
    property bool optionsExpanded: false
    readonly property bool showOptions: !compact || optionsExpanded
    readonly property real previewTop: showOptions ? topOptions.y + topOptions.height + 8 : 36
    readonly property real previewBottom: showOptions ? bottomOptions.height + 20 : 8

    readonly property var draft: studio.draft
    readonly property var cardSize: LayoutSizes.size(draft)
    readonly property bool pill: Schema.isPill(draft)
    readonly property real fitScale: Math.max(0.25, Math.min(1, (width - 40) / (cardSize[0] + (pill ? 160 : 0)), Math.max(0, height - previewTop - previewBottom) / cardSize[1]))
    readonly property real zoomScale: zoom === "fit" ? fitScale : Number(zoom)

    radius: 18
    color: Theme.panel
    border.color: Theme.line2
    border.width: 1
    clip: true

    Backdrop {
        id: stageWallpaper
        anchors.fill: parent
        anchors.margins: 1
        kind: pane.backdrop
    }

    PreviewBackend {
        id: stageBackend
        running: pane.visible && pane.studio.onScreen
        hasAudio: pane.stateName !== "paused" && pane.stateName !== "idle"
        backendFailed: pane.stateName === "backend"
        backendCode: backendFailed ? "no-cava" : ""
        backendMessage: backendFailed ? "cava is not installed" : ""
        backendAction: backendFailed ? "sudo pacman -S cava" : ""
    }
    SamplePlayer {
        id: stagePlayer
        track: pane.stateName === "long" ? "A Very Long Song Title That Keeps Going Past The Edge (Extended Mix)" : pane.stateName === "nometa" ? "https://rr3---sn.googlevideo.com/videoplayback?itag=251&clen=1&gir=yes" : "Slow Tide"
        artist: pane.stateName === "nometa" ? "" : pane.stateName === "long" ? "The Particularly Verbose Orchestra" : "Wren & Hollow"
        artUrl: pane.stateName === "nometa" ? "" : Qt.resolvedUrl("../../../icon.png").toString()
    }

    // Floating Plasma panel or Hyprland bar behind panel forms.
    Rectangle {
        visible: pane.pill
        anchors.centerIn: widgetBox
        width: (pane.cardSize[0] + 160) * pane.zoomScale
        height: (pane.studio.env === "kde" ? 44 : 36) * pane.zoomScale
        radius: (pane.studio.env === "kde" ? 12 : 14) * pane.zoomScale
        color: pane.studio.env === "kde" ? "#e0202326" : "#e611111b"
        border.width: pane.studio.env === "kde" ? 1 : 2
        border.color: pane.studio.env === "kde" ? "#14ffffff" : "#5589b4fa"
    }

    Item {
        id: widgetBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: pane.previewTop + (pane.height - pane.previewTop - pane.previewBottom - height) / 2
        width: pane.cardSize[0] * pane.zoomScale
        height: pane.cardSize[1] * pane.zoomScale
        // Created once the host has supplied a draft.
        Loader {
            active: !!pane.draft && pane.draft.showMpris !== undefined
            sourceComponent: VisualizerView {
                samplePlayback: true
                backdropSource: stageWallpaper
                objectName: "previewWidget"
                width: pane.cardSize[0]
                height: pane.cardSize[1]
                scale: pane.zoomScale
                transformOrigin: Item.TopLeft
                configuration: pane.draft
                visualizer: stageBackend
                player: pane.stateName === "idle" ? null : stagePlayer
                isPlaying: pane.stateName !== "paused"
                accentColor: pane.studio.previewAccent
                systemTextColor: "#eff0f1"
                positionUnitsPerSecond: 1
            }
        }
    }

    component Chip: Rectangle {
        default property alias content: chipRow.data
        width: chipRow.implicitWidth + 8
        height: 30
        radius: 10
        color: "#cc0b0c0d"
        border.color: "#1fffffff"
        border.width: 1
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
        }
    }
    component ChipLabel: Text {
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        leftPadding: 6
        rightPadding: 2
        color: "#8a9187"
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 0.5
    }
    component ChipButton: Rectangle {
        id: chipButton
        property string label: ""
        property bool pressed: false
        signal clicked
        width: buttonLabel.implicitWidth + 16
        height: 22
        radius: 7
        color: pressed ? "#1affffff" : "transparent"
        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: chipButton.label
            color: chipButton.pressed ? "#ffffff" : "#aab1a7"
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chipButton.clicked()
        }
    }

    StudioButton {
        objectName: "previewOptionsToggle"
        visible: pane.compact
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4
        height: 28
        text: pane.optionsExpanded ? "Hide preview options" : "Preview options"
        onClicked: pane.optionsExpanded = !pane.optionsExpanded
    }

    Flow {
        id: topOptions
        visible: pane.showOptions
        x: 12
        y: pane.compact ? 40 : 12
        width: parent.width - 24
        spacing: 8
        Chip {
            ChipLabel {
                text: "WALLPAPER"
            }
            Repeater {
                model: Schema.BACKDROPS
                Item {
                    id: backdropButton
                    objectName: "wallpaper_" + modelData[0]
                    Accessible.name: modelData[1]
                    Controls.ToolTip.visible: wallpaperArea.containsMouse
                    Controls.ToolTip.text: modelData[1]
                    Controls.ToolTip.delay: 400
                    required property var modelData
                    width: 30
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    Backdrop {
                        anchors.fill: parent
                        kind: backdropButton.modelData[0]
                    }
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: pane.backdrop === backdropButton.modelData[0] ? -2 : 0
                        radius: 6
                        color: "transparent"
                        border.width: pane.backdrop === backdropButton.modelData[0] ? 2 : 1
                        border.color: pane.backdrop === backdropButton.modelData[0] ? "#ffffff" : "#30ffffff"
                    }
                    MouseArea {
                        id: wallpaperArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: pane.backdrop = backdropButton.modelData[0]
                    }
                }
            }
        }
        Controls.ComboBox {
            visible: pane.compact
            width: 180
            height: 30
            model: Schema.STATES.map(state => state[1])
            currentIndex: Schema.STATES.findIndex(state => state[0] === pane.stateName)
            onActivated: pane.stateName = Schema.STATES[currentIndex][0]
        }
        Chip {
            visible: !pane.compact
            ChipLabel {
                text: "STATE"
            }
            Repeater {
                model: Schema.STATES
                ChipButton {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    label: modelData[1]
                    pressed: pane.stateName === modelData[0]
                    onClicked: pane.stateName = modelData[0]
                }
            }
        }
    }

    Flow {
        id: bottomOptions
        visible: pane.showOptions
        x: 12
        width: parent.width - 24
        y: parent.height - height - 12
        spacing: 8
        layoutDirection: Qt.RightToLeft
        Chip {
            Repeater {
                model: [["1", "1×"], ["2", "2×"], ["fit", "Fit"]]
                ChipButton {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    label: modelData[1]
                    pressed: pane.zoom === modelData[0]
                    onClicked: pane.zoom = modelData[0]
                }
            }
        }
        Rectangle {
            width: sizeInfo.implicitWidth + 18
            height: 26
            radius: 8
            color: "#cc0b0c0d"
            border.color: "#1affffff"
            border.width: 1
            Text {
                id: sizeInfo
                anchors.centerIn: parent
                text: pane.cardSize[0] + " × " + pane.cardSize[1] + " px · " + pane.zoomScale.toFixed(2) + "×"
                color: "#b0e6ebe3"
                font.family: "monospace"
                font.pixelSize: 10
            }
        }
        Chip {
            ChipLabel {
                text: "ACCENT"
            }
            Repeater {
                model: ["#3daee9", "#a855f7", "#ff6fb0", "#f5b26b", "#34d399"]
                Rectangle {
                    id: accentDot
                    objectName: "previewAccent_" + modelData.slice(1)
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 7
                    color: modelData
                    border.width: pane.draft.useSystemAccent === false && !pane.draft.accentFromArt && Qt.colorEqual(pane.draft.customColor, modelData) ? 2 : 0
                    border.color: "#ffffff"
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pane.studio.update({
                            useSystemAccent: false,
                            accentFromArt: false,
                            customColor: accentDot.modelData
                        })
                    }
                }
            }
        }
    }
}
