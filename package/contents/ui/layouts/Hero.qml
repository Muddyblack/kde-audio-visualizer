import QtQuick
import QtQuick.Layouts
import "../../code/Layouts.js" as Layouts

// Wave fills the top; progress; then [cover 34][texts][dock].
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property bool bg: cfg.showBg
    implicitWidth: Layouts.size(cfg)[0]
    implicitHeight: Layouts.size(cfg)[1]

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.bg ? 14 : 0
        anchors.rightMargin: root.bg ? 14 : 0
        anchors.topMargin: root.bg ? 12 : 0
        anchors.bottomMargin: root.bg ? 10 : 0
        spacing: 6

        LayoutWave {
            view: root.view
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        LayoutProgress {
            view: root.view
            artShown: art.visible
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            LayoutArt {
                id: art
                view: root.view
                size: Math.min(44, 34 * (root.cfg.artScale ?? 100) / 100)
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
            }
            LayoutTexts {
                view: root.view
                Layout.fillWidth: true
            }
            LayoutDock {
                view: root.view
            }
        }
    }
}
