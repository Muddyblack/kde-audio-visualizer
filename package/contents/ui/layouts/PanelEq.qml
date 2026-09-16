import QtQuick

// Four accent EQ bars (HTML `.eq`). Static bars cost no frames; live bars
// bounce on the audio frame clock; paused bars rest at 25 % and .5 opacity.
Row {
    id: eq
    required property var view
    property bool live: false
    property real barWidth: 2.5
    property real barHeight: 12
    readonly property bool paused: !view.isPlaying
    readonly property var restHeights: [0.4, 0.95, 0.6, 0.78]
    readonly property var periods: [900, 700, 1100, 800]

    // Ease-in-out between 25 % and 100 %, alternating like the CSS animation.
    function bounce(index) {
        const period = periods[index];
        const phase = (view.visualFrameTime / period) % 2;
        const x = phase < 1 ? phase : 2 - phase;
        return 0.25 + 0.75 * (0.5 - 0.5 * Math.cos(Math.PI * x));
    }

    spacing: 2
    height: barHeight

    Repeater {
        model: 4
        Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: eq.barWidth
            height: eq.barHeight * (eq.paused ? 0.25 : eq.live ? eq.bounce(index) : eq.restHeights[index])
            radius: 2
            color: eq.view.waveColor
            opacity: eq.paused ? 0.5 : 1
        }
    }
}
