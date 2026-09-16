import QtQuick
import "Theme.js" as Theme

// Audio status and "Run diagnostics" (HTML `.status` / `.check`), fed by the
// host running contents/code/doctor.sh.
Column {
    id: card
    required property var studio
    property string output: ""
    property bool running: false
    readonly property var inputNames: ({
            auto: "Auto-detect",
            pipewire: "PipeWire",
            pulse: "PulseAudio",
            alsa: "ALSA"
        })
    readonly property int effectiveRate: studio.draft.batterySaver ? Math.min(20, studio.draft.framerate ?? 30) : (studio.draft.framerate ?? 30)
    readonly property var checks: parse(output)
    spacing: 6

    function field(text, pattern) {
        const match = text.match(pattern);
        return match ? match[1].trim() : "";
    }
    function parse(text) {
        if (!text)
            return [];
        const missing = /NOT INSTALLED/.test(text);
        const path = field(text, /^path:\s*(.+)$/m);
        const backends = field(text, /^backends built in:\s*(.+)$/m);
        const server = field(text, /^pactl server:\s*(.+)$/m);
        const sink = field(text, /^default sink:\s*(.+)$/m);
        return [["cava found", !missing && path !== "", missing ? "not installed" : path], ["Capture backends", backends !== "", backends || "unknown"], ["Sound server", server !== "", server || "not reachable"], ["Default output", sink !== "", sink || "none"], ["Renderer", true, GraphicsInfo.api === GraphicsInfo.Software ? "canvas (software)" : "shader"]];
    }

    Item {
        width: card.width
        height: 48
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            radius: 5
            color: Theme.ok
        }
        Column {
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - runButton.width - 12
            Text {
                text: "Audio capture"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                text: (card.inputNames[card.studio.draft.inputMethod] ?? "Auto-detect") + " · " + card.effectiveRate + " Hz · " + (card.studio.draft.numBars ?? 24) + " bars"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        StudioButton {
            id: runButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            visible: typeof card.studio.diagnosticsRunner === "function"
            text: card.running ? "Running…" : "Run diagnostics"
            onClicked: {
                if (card.running)
                    return;
                card.running = true;
                card.studio.diagnosticsRunner(text => {
                    card.output = text;
                    card.running = false;
                });
            }
        }
    }

    Repeater {
        model: card.checks
        Item {
            id: check
            required property var modelData
            width: card.width
            height: 30
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: check.modelData[1] ? "#227fd18a" : "#22f1c27b"
                Text {
                    anchors.centerIn: parent
                    text: check.modelData[1] ? "✓" : "!"
                    color: check.modelData[1] ? Theme.ok : Theme.warn
                    font.pixelSize: 10
                }
            }
            Text {
                x: 28
                anchors.verticalCenter: parent.verticalCenter
                text: check.modelData[0]
                color: check.modelData[1] ? Theme.text : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - 160)
                text: check.modelData[2]
                color: Theme.dim
                font.family: "monospace"
                font.pixelSize: 10
                elide: Text.ElideLeft
            }
        }
    }
}
