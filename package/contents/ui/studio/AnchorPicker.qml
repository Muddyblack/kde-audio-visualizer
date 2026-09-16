import QtQuick

// Screen position (HTML `.monitor .anch`): a monitor with a 3 × 3 anchor grid.
Item {
    id: picker
    required property var studio
    readonly property var spots: {
        const out = [];
        for (const v of [0.08, 0.5, 0.92])
            for (const h of ["left", "center", "right"])
                out.push([h, v]);
        return out;
    }
    implicitWidth: 340
    implicitHeight: monitor.height

    Rectangle {
        id: monitor
        width: Math.min(340, picker.width)
        height: width * 9 / 16
        radius: 10
        color: "#2a2d2f"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            anchors.bottomMargin: 10
            radius: 5
            clip: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: "#3a2f5e"
                }
                GradientStop {
                    position: 1
                    color: "#b3628a"
                }
            }
            Grid {
                anchors.fill: parent
                anchors.margins: 8
                columns: 3
                rows: 3
                spacing: 4
                Repeater {
                    model: picker.spots
                    Rectangle {
                        id: spot
                        required property var modelData
                        readonly property bool pressed: (picker.studio.draft.hAnchor ?? "center") === modelData[0] && Math.abs((picker.studio.draft.verticalPosition ?? 0.6) - modelData[1]) < 0.21
                        width: (parent.width - 8) / 3
                        height: (parent.height - 8) / 3
                        radius: 6
                        color: "transparent"
                        border.width: 1
                        border.color: pressed ? "#ffffff" : "#30ffffff"
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.46
                            height: parent.height * 0.24
                            radius: 4
                            color: spot.pressed ? "#ffffff" : "#26ffffff"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: picker.studio.update({
                                hAnchor: spot.modelData[0],
                                verticalPosition: spot.modelData[1]
                            })
                        }
                    }
                }
            }
        }
    }
}
