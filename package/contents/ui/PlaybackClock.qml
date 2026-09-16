import QtQuick

// Predict between MPRIS signals only while the progress bar can be seen.
// Keep the time anchor while hidden so showing it catches up immediately.
Item {
    id: clock

    property var player: null
    property bool playing: false
    property bool active: true
    property string track: ""
    property real lengthValue: 0
    property real displayedPosition: 0
    property real anchorPosition: 0
    property real anchorMs: Date.now()
    property real unitScale: 0
    property int updateInterval: 50
    readonly property real unitsPerSecond: unitScale > 0 ? unitScale : lengthValue >= 1000000 ? 1000000 : lengthValue >= 10000 ? 1000 : 1
    readonly property real progress: lengthValue > 0 ? clamp(displayedPosition / lengthValue, 0, 1) : 0
    // Quantize before formatting: the label changes once a second even though
    // the smooth progress fill still advances every 50 ms.
    readonly property int elapsedSeconds: Math.max(0, Math.floor(displayedPosition / unitsPerSecond))
    readonly property int totalSeconds: Math.max(0, Math.floor(lengthValue / unitsPerSecond))
    readonly property string elapsedText: formatTime(elapsedSeconds)
    readonly property string totalText: formatTime(totalSeconds)
    readonly property int remainingSeconds: Math.max(0, Math.floor((lengthValue - displayedPosition) / unitsPerSecond))
    readonly property string remainingText: "-" + formatTime(remainingSeconds)
    readonly property bool ticking: active && playing && !!player && lengthValue > 0 && displayedPosition < lengthValue

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function predictedPosition() {
        if (!playing)
            return anchorPosition;
        return clamp(anchorPosition + (Date.now() - anchorMs) * unitsPerSecond / 1000, 0, lengthValue);
    }

    function setPosition(position) {
        anchorPosition = clamp(position, 0, lengthValue);
        anchorMs = Date.now();
        displayedPosition = anchorPosition;
    }

    // Both linear bars and cover rings seek in the player's native units.
    function seekToFraction(fraction) {
        const p = player;
        if (!p || p.canControl === false || p.canSeek === false || p.positionSupported === false)
            return false;
        const length = p.length || p.mprisLength || 0;
        if (!Number.isFinite(length) || length <= 0 || !Number.isFinite(fraction))
            return false;
        const position = clamp(fraction, 0, 1) * length;
        if (p.position !== undefined)
            p.position = position;
        else if (typeof p.SetPosition === "function")
            p.SetPosition(position);
        else if (typeof p.setPosition === "function")
            p.setPosition(position);
        else
            return false;
        setPosition(position);
        return true;
    }

    function syncFromPlayer(hard) {
        const len = player ? Math.max(0, player.length || player.mprisLength || 0) : 0;
        // Some players briefly clear length while updating metadata.
        if (len > 0 || !player)
            lengthValue = len;
        if (len <= 0) {
            if (!player)
                setPosition(0);
            return;
        }
        const rawPosition = clamp(player.position || 0, 0, lengthValue);
        const drift = Math.abs(rawPosition - predictedPosition());
        anchorPosition = rawPosition;
        anchorMs = Date.now();
        if (hard || drift > unitsPerSecond * 1.25 || !playing || displayedPosition <= 0 || displayedPosition >= lengthValue)
            displayedPosition = rawPosition;
    }

    function tick() {
        if (lengthValue > 0)
            displayedPosition = predictedPosition();
    }

    function twoDigits(value) {
        return value < 10 ? "0" + value : "" + value;
    }

    function formatTime(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        return hours > 0 ? hours + ":" + twoDigits(minutes) + ":" + twoDigits(secs) : minutes + ":" + twoDigits(secs);
    }

    onPlayerChanged: {
        // A different player must not inherit the previous player's duration.
        // Only transient empty metadata from the same player is retained.
        lengthValue = 0;
        setPosition(0);
        syncFromPlayer(true);
    }
    onPlayingChanged: syncFromPlayer(true)
    onTrackChanged: syncFromPlayer(true)
    onActiveChanged: {
        if (active)
            tick();
    }
    Component.onCompleted: syncFromPlayer(true)

    Connections {
        target: clock.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            clock.syncFromPlayer(false);
        }
        function onLengthChanged() {
            clock.syncFromPlayer(true);
        }
        function onMprisLengthChanged() {
            clock.syncFromPlayer(true);
        }
    }

    Timer {
        interval: clock.updateInterval
        running: clock.ticking
        repeat: true
        onTriggered: clock.tick()
    }
}
