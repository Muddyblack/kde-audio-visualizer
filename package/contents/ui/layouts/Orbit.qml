import QtQuick
import QtQuick.Layouts
import ".."
import "../../code/Layouts.js" as Layouts

// Square ring box with the cover in the centre and the visualizer around it;
// centred title/artist, progress and dock below.
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property bool bg: cfg.showBg
    readonly property real box: Math.max(0, width - (bg ? 60 : 28))
    readonly property real coverSize: Math.round(Math.min(box * 0.56, box * 0.38 * (cfg.artScale ?? 100) / 100))
    implicitWidth: Layouts.size(cfg)[0]
    implicitHeight: Layouts.size(cfg)[1]

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.bg ? 16 : 4
        anchors.rightMargin: root.bg ? 16 : 4
        anchors.topMargin: root.bg ? 14 : 4
        anchors.bottomMargin: root.bg ? 12 : 4
        spacing: 8

        Item {
            Layout.preferredWidth: root.box
            Layout.preferredHeight: root.box
            Layout.alignment: Qt.AlignHCenter

            OrbitView {
                simpleRender: root.cfg.simpleRender ?? false
                objectName: "orbitCanvas"
                anchors.fill: parent
                coverRatio: root.box > 0 ? root.coverSize / root.box : 0.38
                bars: root.view.visualizer.bars ?? []
                numBars: root.view.visualizer.numBars ?? 24
                maxRange: root.view.visualizer.maxRange ?? 1000
                hasAudio: root.view.visualizer.hasAudio ?? false
                backendFailed: root.view.visualizer.backendFailed ?? false
                visualFrameTime: root.view.visualFrameTime
                high: root.view.visualizer.high ?? 0
                waveColor: root.view.waveColor
                coverColor1: root.view.coverColor1
                coverColor2: root.view.coverColor2
                vizColorMode: root.cfg.vizColorMode ?? "solid"
                vizPalette: root.cfg.vizPalette ?? "aurora"
                hueReactive: root.cfg.hueReactive ?? false
                lineWidth: root.cfg.lineWidth
                fillWave: root.cfg.fillWave
                glowWave: root.cfg.glowWave && !root.view.batterySaving
                bloom: root.cfg.bloom ?? 1
                reducedMotion: root.cfg.reducedMotion ?? false
                orbitStyle: root.cfg.orbitStyle ?? "bars"
                orbitReach: root.cfg.orbitReach ?? 1
                orbitRotate: root.cfg.orbitRotate ?? true
            }

            LayoutArt {
                id: art
                anchors.centerIn: parent
                width: implicitWidth
                height: implicitHeight
                view: root.view
                size: root.coverSize
                ringShrink: 8
                // The cover breathes with the bass, which arrives with audio frames.
                scale: (root.cfg.orbitCoverPulse ?? true) && !(root.cfg.reducedMotion ?? false) ? 1 + (root.view.visualizer.bass ?? 0) * 0.07 : 1
            }
        }
        LayoutTexts {
            view: root.view
            titleFactor: 1.3
            artistSize: 0.95
            alignmentOverride: Text.AlignHCenter
            Layout.fillWidth: true
        }
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
        Item {
            Layout.fillHeight: true
        }
    }
}
