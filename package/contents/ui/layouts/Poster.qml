import QtQuick
import QtQuick.Layouts
import "../../code/Layouts.js" as Layouts

// Typographic card: the wave as a faded texture behind an accent meta line, a
// large title, and a [progress][clock][dock] footer. No cover.
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property bool bg: cfg.showBg
    readonly property bool centered: cfg.posterAlign === "center"
    readonly property bool showClock: (cfg.posterClock ?? true) && view.hasPlayer
    readonly property real ts: cfg.titleSize ?? 11
    implicitWidth: Layouts.size(cfg)[0]
    implicitHeight: Layouts.size(cfg)[1]

    Item {
        id: area
        anchors.fill: parent
        anchors.leftMargin: root.bg ? 16 : 2
        anchors.rightMargin: root.bg ? 16 : 2
        anchors.topMargin: root.bg ? 12 : 4
        anchors.bottomMargin: root.bg ? 10 : 4

        LayoutWave {
            objectName: "posterTexture"
            view: root.view
            anchors.fill: parent
            visible: root.cfg.posterVizBehind ?? true
            opacity: (root.cfg.posterVizOpacity ?? 0.35) * (faded ? 0.28 : 1)
            edgeFade: true
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 2

            Item {
                Layout.fillHeight: true
            }
            RowLayout {
                spacing: 6
                Layout.maximumWidth: area.width
                Layout.fillWidth: !root.centered
                Layout.alignment: root.centered ? Qt.AlignHCenter : Qt.AlignLeft
                opacity: 0.72

                Rectangle {
                    implicitWidth: 5
                    implicitHeight: 5
                    radius: 1
                    rotation: 45
                    color: root.view.waveColor
                }
                Text {
                    renderType: Text.CurveRendering ?? Text.QtRendering
                    objectName: "posterMeta"
                    Layout.fillWidth: !root.centered
                    Layout.maximumWidth: area.width - 11
                    text: [root.view.artist !== "" ? root.view.artist : root.view.sourceHint, (root.cfg.showAlbum ?? false) ? root.view.album : ""].filter(Boolean).join(" · ").toUpperCase() || " "
                    font.pixelSize: 8
                    font.letterSpacing: 1.6
                    font.italic: root.view.artist === "" && root.view.sourceHint !== ""
                    color: root.view.textColor
                    elide: Text.ElideRight
                }
            }
            Text {
                renderType: Text.CurveRendering ?? Text.QtRendering
                objectName: "posterTitle"
                Layout.fillWidth: true
                text: root.view.idleMessage ? qsTr("Nothing playing") : root.view.trackUnknown ? qsTr("No track metadata") : (root.view.displayTrack || " ")
                horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
                font.pixelSize: Math.round(root.ts * 2.1)
                font.weight: root.view.trackUnknown || root.view.idleMessage ? Font.Normal : Font.ExtraBold
                font.italic: root.view.trackUnknown
                font.letterSpacing: -0.02 * Math.round(root.ts * 2.1)
                opacity: root.view.idleMessage ? 0.55 : root.view.trackUnknown ? 0.75 : 1
                lineHeight: 1.08
                wrapMode: Text.Wrap
                maximumLineCount: root.cfg.posterLines === 2 ? 2 : 1
                elide: Text.ElideRight
                color: root.view.textColor
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 5
                spacing: 10
                LayoutProgress {
                    id: progress
                    view: root.view
                    hideTimes: root.cfg.posterClock ?? true
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                }
                Text {
                    renderType: Text.CurveRendering ?? Text.QtRendering
                    objectName: "posterClock"
                    visible: root.showClock
                    text: progress.elapsedText
                    font.family: "monospace"
                    font.weight: Font.DemiBold
                    font.pixelSize: Math.round(root.ts * 1.25)
                    font.letterSpacing: -0.02 * Math.round(root.ts * 1.25)
                    font.features: {
                        "tnum": 1
                    }
                    opacity: 0.85
                    color: root.view.textColor
                }
                LayoutDock {
                    view: root.view
                }
            }
        }
    }
}
