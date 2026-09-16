import QtQuick
import QtQuick.Controls.Basic as Controls

// A separate transient window lets even a small panel icon show a useful cover.
Window {
    id: lightbox
    required property var view
    objectName: "artZoom"
    transientParent: view.Window.window
    flags: Qt.Tool
    color: "#111416"
    title: view.displayTrack
    width: Math.min(460, Screen.desktopAvailableWidth > 0 ? Screen.desktopAvailableWidth - 40 : 460)
    height: Math.min(560, Screen.desktopAvailableHeight > 0 ? Screen.desktopAvailableHeight - 60 : 560)
    visible: view.zoomOpen && view.visible && view.shouldShow
    onClosing: view.zoomOpen = false

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: lightbox.view.zoomOpen = false
        MouseArea {
            objectName: "artZoomArea"
            anchors.fill: parent
            onClicked: lightbox.view.zoomOpen = false
        }
        Column {
            anchors.centerIn: parent
            spacing: 14
            width: parent.width - 48
            ArtView {
                objectName: "zoomArt"
                width: Math.max(0, Math.min(parent.width, lightbox.height - 130))
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                artUrl: lightbox.view.artUrl
                desktopEntry: lightbox.view.desktopEntry
                fallbackIcon: lightbox.view.fallbackIcon
            }
            Text {
                width: parent.width
                text: lightbox.view.displayTrack
                color: "#eff0f1"
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 2
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: lightbox.view.artist
                color: "#aeb7bc"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
        Controls.ToolButton {
            anchors.top: parent.top
            anchors.right: parent.right
            text: "×"
            Accessible.name: qsTr("Close artwork")
            onClicked: lightbox.view.zoomOpen = false
        }
    }
}
