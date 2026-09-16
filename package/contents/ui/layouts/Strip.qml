import QtQuick
import QtQuick.Layouts
import "../../code/Layouts.js" as Layouts

// One row: [cover][texts 120][wave][dock].
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property bool bg: cfg.showBg
    implicitWidth: Layouts.size(cfg)[0]
    implicitHeight: Layouts.size(cfg)[1]

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.bg ? 6 : 2
        anchors.rightMargin: root.bg ? 8 : 2
        anchors.topMargin: root.bg ? 6 : 2
        anchors.bottomMargin: root.bg ? 6 : 2
        spacing: 10

        LayoutArt {
            view: root.view
            size: root.height - (root.bg ? 12 : 4)
            ringShrink: 6
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.alignment: Qt.AlignVCenter
        }
        LayoutTexts {
            view: root.view
            Layout.preferredWidth: 120
            Layout.minimumWidth: 120
            Layout.maximumWidth: 120
            Layout.alignment: Qt.AlignVCenter
        }
        LayoutWave {
            view: root.view
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
        }
        LayoutDock {
            view: root.view
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
