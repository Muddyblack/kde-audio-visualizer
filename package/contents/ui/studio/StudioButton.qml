import QtQuick
import "Theme.js" as Theme

// HTML `.ghost` (outlined) and `.primary` (brand) buttons.
Rectangle {
    id: control
    property string text: ""
    property bool primary: false
    property bool compact: false
    property string areaName: ""
    signal clicked

    implicitWidth: label.implicitWidth + 24
    implicitHeight: compact || primary ? 28 : 36
    radius: compact || primary ? 8 : 10
    color: primary ? Theme.brand : area.containsMouse ? Theme.hover : "transparent"
    border.width: primary ? 0 : 1
    border.color: Theme.line2

    Text {
        id: label
        anchors.centerIn: parent
        text: control.text
        color: control.primary ? Theme.brandInk : area.containsMouse ? Theme.text : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: control.primary ? Font.DemiBold : Font.Normal
    }
    MouseArea {
        id: area
        objectName: control.areaName
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.clicked()
    }
}
