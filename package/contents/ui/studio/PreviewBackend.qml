import QtQuick

// Synthetic audio for the settings previews (docs/redesign-plan.md §9.4 and
// P9): at most 15 Hz and only while `running`; a stopped backend keeps one
// still frame for static thumbnails.
Item {
    id: backend
    property bool running: true
    property int numBars: 24
    property real maxRange: 1000
    property var bars: []
    property real frameTimeMs: 0
    property bool hasAudio: true
    property bool backendFailed: false
    property string backendCode: ""
    property string backendMessage: ""
    property string backendAction: ""
    property string backendHint: ""
    property bool plasmoidVisible: true
    property real bass: 0
    property real mid: 0
    property real high: 0
    property bool attack: false

    function frame(now) {
        const t = now / 1000;
        const kick = Math.pow(0.5 + 0.5 * Math.sin(t * 7.4), 7);
        const out = new Array(numBars);
        for (let i = 0; i < numBars; i++) {
            const p = numBars > 1 ? i / (numBars - 1) : 0;
            const shape = 0.18 + 0.5 * Math.pow(Math.sin(p * Math.PI), 0.8);
            const wobble = 0.55 + 0.45 * Math.sin(t * 3.1 + i * 0.7) * Math.sin(t * 1.3 + i * 0.23);
            const low = p < 0.3 ? kick * 0.35 * (1 - p / 0.3) : 0;
            out[i] = maxRange * Math.min(1, shape * wobble + low);
        }
        bars = out;
        frameTimeMs = now;
        bass = kick;
        mid = 0.5 + 0.5 * Math.sin(t * 1.3);
        high = 0.5 + 0.5 * Math.sin(t * 5.1 + 1);
        attack = kick > 0.86;
    }

    Timer {
        interval: 67
        running: backend.running && backend.hasAudio && !backend.backendFailed
        repeat: true
        onTriggered: backend.frame(Date.now())
    }
    Component.onCompleted: frame(2375)
}
