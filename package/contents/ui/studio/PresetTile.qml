import QtQuick
import QtQuick.Controls.Basic as Controls
import ".."
import "Theme.js" as Theme
import "../../code/Layouts.js" as LayoutSizes

// A look tile (HTML `.pp`): a still, scaled widget over its backdrop.
Item {
    id: tile
    required property var studio
    property string name: ""
    property string backdrop: "dusk"
    property var settings: ({})
    property bool active: false
    property bool deletable: false
    property bool renamable: false
    property bool renaming: false
    signal renamed(string name)
    function finishRename() {
        if (!renaming)
            return;
        const value = renameInput.text.trim();
        if (!value) {
            renameInput.forceActiveFocus();
            return;
        }
        renaming = false;
        if (value !== name)
            renamed(value);
    }
    signal picked
    signal removed

    readonly property var cardSize: LayoutSizes.size(settings)
    height: 68 + 12 + 20

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: 15
        visible: tile.active
        color: "transparent"
        border.width: 3
        border.color: Theme.tileSelectedRing
    }
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.sunk
        border.width: 1
        border.color: tile.active ? Theme.tileSelectedBorder : hover.hovered ? Theme.tileHoverBorder : Theme.line2
        transform: Translate {
            y: hover.hovered ? -1 : 0
        }

        Item {
            id: previewArea
            x: 6
            y: 6
            width: parent.width - 12
            height: 68
            clip: true
            Backdrop {
                id: tileWallpaper
                anchors.fill: parent
                kind: tile.backdrop
            }
            Item {
                readonly property real fit: Math.min(1.25, (previewArea.width - 12) / tile.cardSize[0], (previewArea.height - 10) / tile.cardSize[1])
                anchors.centerIn: parent
                width: tile.cardSize[0] * fit
                height: tile.cardSize[1] * fit
                Loader {
                    // A preset patch alone is not a complete preview configuration.
                    active: tile.settings.numBars !== undefined && tile.settings.showMpris !== undefined
                    sourceComponent: VisualizerView {
                        samplePlayback: true
                        backdropSource: tileWallpaper
                        width: tile.cardSize[0]
                        height: tile.cardSize[1]
                        scale: parent.parent.fit
                        transformOrigin: Item.TopLeft
                        configuration: tile.settings
                        visualizer: tile.studio.stillBackend
                        player: tile.studio.samplePlayer
                        isPlaying: true
                        accentColor: tile.studio.previewAccent
                        systemTextColor: "#eff0f1"
                        positionUnitsPerSecond: 1
                        enabled: false
                    }
                }
            }
        }
        Row {
            visible: !tile.renaming
            x: 9
            y: 78
            width: parent.width - 18
            spacing: 4
            Text {
                width: parent.width - check.width - 4
                text: tile.name
                textFormat: Text.PlainText
                color: tile.active ? Theme.text : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                id: check
                visible: tile.active
                text: "✓"
                color: Theme.brand
                font.pixelSize: 11
            }
        }
    }
    HoverHandler {
        id: hover
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: !tile.renaming
        onClicked: tile.picked()
    }
    Controls.ToolButton {
        objectName: "renamePresetButton"
        visible: tile.renamable
        x: parent.width - width - 34
        y: 7
        width: 24
        height: 24
        text: "✎"
        Accessible.name: "Rename preset"
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.text: "Rename preset"
        contentItem: Text {
            text: parent.text
            color: "white"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 6
            color: "#cc101214"
        }
        onClicked: {
            tile.renaming = true;
            renameInput.text = tile.name;
            renameInput.forceActiveFocus();
            renameInput.selectAll();
        }
    }
    Rectangle {
        visible: tile.renaming
        x: 6
        y: 75
        width: parent.width - 12
        height: 22
        radius: 4
        color: Theme.sunk
        border.color: Theme.brand
        TextInput {
            id: renameInput
            objectName: "renamePresetInput"
            anchors.fill: parent
            anchors.margins: 3
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 11
            clip: true
            selectByMouse: true
            Accessible.name: "Preset name"
            onAccepted: tile.finishRename()
            Keys.onEscapePressed: tile.renaming = false
        }
    }
    Rectangle {
        visible: tile.deletable && hover.hovered
        x: parent.width - width - 9
        y: 9
        width: 20
        height: 20
        radius: 10
        color: "#bb000000"
        Text {
            anchors.centerIn: parent
            text: "×"
            color: "#ffffff"
            font.pixelSize: 12
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.removed()
        }
    }
}
