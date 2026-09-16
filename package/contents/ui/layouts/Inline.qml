import QtQuick
import QtQuick.Layouts
import "../../code/Layouts.js" as Layouts

// Tall cover left; texts, a wave (≤34 px) and a [progress][dock] row right.
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property bool bg: cfg.showBg
    implicitWidth: Layouts.size(cfg)[0]
    implicitHeight: Layouts.size(cfg)[1]

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.bg ? 8 : 0
        anchors.rightMargin: root.bg ? 12 : 0
        anchors.topMargin: root.bg ? 8 : 0
        anchors.bottomMargin: root.bg ? 6 : 0
        spacing: 12

        LayoutArt {
            id: art
            view: root.view
            size: Math.min(root.height - (root.bg ? 14 : 4), (root.height - (root.bg ? 16 : 8)) * (root.cfg.artScale ?? 100) / 100)
            ringShrink: 8
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
            id: column
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                Layout.fillHeight: true
            }
            LayoutTexts {
                id: texts
                view: root.view
                Layout.fillWidth: true
            }
            LayoutWave {
                view: root.view
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(0, Math.min(34, column.height - texts.implicitHeight - footer.implicitHeight))
            }
            RowLayout {
                id: footer
                Layout.fillWidth: true
                spacing: 8
                LayoutProgress {
                    view: root.view
                    artShown: art.visible
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                }
                LayoutDock {
                    view: root.view
                }
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
}
