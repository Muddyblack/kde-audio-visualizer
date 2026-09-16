import QtQuick

// A 20 px round panel-pill button (HTML `.pctl button`) with a 10 px icon from
// the HTML's 24-unit SVG paths.
Item {
    id: button
    property string icon: "play"
    property color color: "#ffffff"
    property string areaName: ""
    signal clicked

    readonly property var paths: ({
            prev: "M19 4 5 12l14 8z",
            next: "m5 4 14 8-14 8z",
            play: "m6 3 15 9-15 9z",
            pause: "M5 3h5v18H5zM14 3h5v18h-5z"
        })

    implicitWidth: 20
    implicitHeight: 20

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0x1a / 255)
        visible: area.containsMouse
    }
    Canvas {
        anchors.centerIn: parent
        width: 10
        height: 10
        opacity: area.containsMouse ? 1 : 0.8
        readonly property var signature: [button.icon, button.color]
        onSignatureChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.scale(width / 24, height / 24);
            ctx.fillStyle = button.color;
            ctx.path = button.paths[button.icon] ?? "";
            ctx.fill();
        }
    }
    MouseArea {
        id: area
        objectName: button.areaName
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
