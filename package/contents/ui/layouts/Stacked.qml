import QtQuick
import QtQuick.Layouts
import "../../code/Layouts.js" as Layouts

// [cover 64][large title / artist]; a 40 px wave; progress; dock centred.
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property bool bg: cfg.showBg
    implicitWidth: Layouts.size(cfg)[0]
    implicitHeight: Layouts.size(cfg)[1]

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.bg ? 20 : 4
        anchors.rightMargin: root.bg ? 20 : 4
        anchors.topMargin: root.bg ? 18 : 4
        anchors.bottomMargin: root.bg ? 14 : 4
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            LayoutArt {
                id: art
                view: root.view
                size: Math.min(84, 64 * (root.cfg.artScale ?? 100) / 100)
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
            }
            LayoutTexts {
                view: root.view
                titleFactor: 1.6
                artistSize: 1.05
                albumSize: 0.85
                lyricSize: 0.85
                sourceSize: 8
                Layout.fillWidth: true
            }
        }
        LayoutWave {
            view: root.view
            Layout.fillWidth: true
            Layout.preferredHeight: 40
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            LayoutProgress {
                view: root.view
                artShown: art.visible
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
            }
            LayoutDock {
                view: root.view
                Layout.alignment: Qt.AlignHCenter
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
