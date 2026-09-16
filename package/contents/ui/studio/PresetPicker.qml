import QtQuick
import "Theme.js" as Theme
import "Schema.js" as Schema

// Built-in looks (HTML `.pp-grid`): filters, "Keep my colours", 150 px tiles.
Column {
    id: picker
    required property var studio
    readonly property int columns: Math.max(1, Math.floor((width + 8) / 158))
    readonly property real tileWidth: (width - (columns - 1) * 8) / columns
    spacing: 10

    Flow {
        width: parent.width
        spacing: 10
        Flow {
            spacing: 6
            Repeater {
                model: Schema.FILTERS
                Rectangle {
                    id: filter
                    required property var modelData
                    readonly property bool pressed: picker.studio.presetFilter === modelData[0]
                    width: filterLabel.implicitWidth + 24
                    height: filterLabel.implicitHeight + 10
                    radius: height / 2
                    color: pressed ? Theme.brand : Theme.hover
                    border.width: pressed ? 0 : 1
                    border.color: Theme.line2
                    Text {
                        id: filterLabel
                        anchors.centerIn: parent
                        text: filter.modelData[1]
                        color: filter.pressed ? Theme.brandInk : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: picker.studio.presetFilter = filter.modelData[0]
                    }
                }
            }
        }
        Row {
            spacing: 8
            height: 24
            StudioSwitch {
                anchors.verticalCenter: parent.verticalCenter
                checked: picker.studio.keepColors
                onToggled: checked => picker.studio.keepColors = checked
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Keep my colours"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }

    Flow {
        width: parent.width
        spacing: 8
        Repeater {
            model: Schema.PRESETS.length
            PresetTile {
                required property int index
                readonly property var look: Schema.PRESETS[index]
                objectName: "preset_" + look.id
                visible: picker.studio.presetFilter === "all" || look.cat.indexOf(picker.studio.presetFilter) !== -1
                width: picker.tileWidth
                studio: picker.studio
                name: look.name
                backdrop: look.bd
                settings: Schema.applyPreset(picker.studio.defaults, {}, look.s, false)
                active: Schema.matchesPreset(picker.studio.defaults, picker.studio.draft, look)
                onPicked: picker.studio.applyLook(look.s)
            }
        }
    }
}
