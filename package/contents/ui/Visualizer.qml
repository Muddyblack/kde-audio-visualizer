import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: vis

    property int numBars: plasmoid.configuration.numBars
    property real maxRange: 1000.0
    property var bars: Array(numBars).fill(0)
    property bool active: true
    property int idleCounter: 0
    property bool restarting: false

    // plasmoid.visible is undefined inside plasmoidviewer (only the real shell
    // sets it), which makes `running: active && plasmoid.visible` evaluate to
    // undefined → timers never start → no data → frozen idle line. Coerce to a
    // real bool, defaulting to visible when the property is absent.
    readonly property bool plasmoidVisible: (plasmoid.visible === undefined) ? true : plasmoid.visible

    readonly property string feederPath: Qt.resolvedUrl("../code/feeder.sh").toString().replace(/^file:\/\//, "")

    Plasma5Support.DataSource {
        id: feederLauncher
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source);
        }
        function spawn() {
            const args = [plasmoid.configuration.numBars, plasmoid.configuration.framerate, plasmoid.configuration.sensitivity, plasmoid.configuration.noiseReduction].join(" ");
            connectSource("bash " + vis.feederPath + " " + args);
        }
        function killFeeder() {
            connectSource("bash -lc \"pkill -f '" + vis.feederPath + "'; pkill -f 'cava -p .*audio-wave-widget'\"");
        }
    }

    // Resolved at startup by pathResolver — no shell expansion needed after that.
    property string resolvedBarsPath: ""

    Plasma5Support.DataSource {
        id: pathResolver
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source);
            const p = (data["stdout"] || "").trim();
            if (p)
                vis.resolvedBarsPath = p;
        }
    }

    Component.onCompleted: {
        // Resolve $XDG_RUNTIME_DIR once at startup so we can use the absolute path
        // without spawning a shell to expand variables on every frame.
        pathResolver.connectSource("echo -n ${XDG_RUNTIME_DIR:-/tmp}/audio-wave-widget/bars");
    }

    // Reader uses pre-resolved path (no shell expansion per frame).
    Plasma5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source);
            vis.handleData((data["stdout"] || "").trim());
        }
        function read() {
            if (vis.resolvedBarsPath)
                connectSource("cat " + vis.resolvedBarsPath);
        }
    }

    readonly property int pollInterval: Math.round(1000 / plasmoid.configuration.framerate)

    // Exponential moving average toward each new cava frame. Cava already
    // smooths over time, but reading a fresh frame every poll still snaps
    // visibly; blending softens the motion without adding latency you'd notice.
    // 0 = frozen, 1 = no smoothing (raw snap). ~0.55 reads as fluid.
    readonly property real smoothing: 0.55

    // Treat the bottom slice of the range as silence. Cava's noise floor and
    // residual smoothing leave tiny non-zero values even when nothing plays, so
    // a strict `val > 0` idle test never trips. Anything under this is "quiet".
    readonly property real idleThreshold: maxRange * 0.012

    function handleData(line) {
        if (!line)
            return;
        const rawParts = line.split(";");
        const parts = [];
        for (let i = 0; i < rawParts.length; i++) {
            if (rawParts[i] !== "")
                parts.push(rawParts[i]);
        }
        if (!parts.length)
            return;
        const prev = bars;
        const out = [];
        let isQuiet = true;
        const a = smoothing;
        for (let i = 0; i < numBars; i++) {
            // Keep animating even if the feeder is briefly still on the old bar
            // count while cava restarts after a config change.
            const sourceIndex = Math.min(parts.length - 1, Math.floor(i * parts.length / numBars));
            const v = parseFloat(parts[sourceIndex]);
            const target = isNaN(v) ? 0 : v;
            if (target > idleThreshold)
                isQuiet = false;
            const p = prev[i] || 0;
            out.push(p + a * (target - p));
        }
        bars = out;

        if (restarting) {
            pollTimer.interval = vis.pollInterval;
        } else if (isQuiet) {
            if (idleCounter < plasmoid.configuration.framerate * 3) {
                idleCounter++;
            } else {
                pollTimer.interval = 500; // Slow down to 2 FPS when idle
            }
        } else {
            idleCounter = 0;
            pollTimer.interval = vis.pollInterval;
        }
    }

    Timer {
        id: pollTimer
        interval: vis.pollInterval
        running: vis.active && vis.plasmoidVisible
        repeat: true
        onTriggered: reader.read()
    }

    // Keep the feeder alive. spawn() is guarded by flock in feeder.sh, so a
    // re-spawn while cava is healthy is a cheap no-op (it exits immediately).
    // We still avoid hammering it: fire once on start to get cava up fast, then
    // fall back to a slow 30s heartbeat that recovers from a crashed feeder.
    Timer {
        interval: 30000
        running: vis.plasmoidVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: feederLauncher.spawn()
    }

    function restart() {
        vis.restarting = true;
        vis.idleCounter = 0;
        vis.bars = Array(vis.numBars).fill(0);
        pollTimer.interval = vis.pollInterval;
        feederLauncher.killFeeder();
        restartTimer.start();
        restartCooldown.start();
    }

    Timer {
        id: restartTimer
        interval: 150
        repeat: false
        onTriggered: feederLauncher.spawn()
    }

    Timer {
        id: restartCooldown
        interval: 1200
        repeat: false
        onTriggered: vis.restarting = false
    }

    Connections {
        target: plasmoid.configuration
        ignoreUnknownSignals: true
        function onNumBarsChanged() {
            vis.bars = Array(vis.numBars).fill(0);
            vis.restart();
        }
        function onSensitivityChanged() {
            vis.restart();
        }
        function onFramerateChanged() {
            vis.restart();
        }
        function onNoiseReductionChanged() {
            vis.restart();
        }
    }

    Component.onDestruction: feederLauncher.killFeeder()
}
