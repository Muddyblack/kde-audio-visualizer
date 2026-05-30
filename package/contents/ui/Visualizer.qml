import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

Item {
    id: vis

    property int numBars: plasmoid.configuration.numBars
    property real maxRange: 600.0
    property var bars: Array(numBars).fill(0)
    property bool active: true
    property int idleCounter: 0

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
            connectSource("pkill -f " + vis.feederPath + " ; pkill -f 'cava -p .*audio-wave-widget'");
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

    function handleData(line) {
        if (!line)
            return;
        const parts = line.split(";");
        if (parts.length < numBars)
            return;
        const out = [];
        let isZero = true;
        for (let i = 0; i < numBars; i++) {
            const v = parseFloat(parts[i]);
            const val = isNaN(v) ? 0 : v;
            if (val > 0)
                isZero = false;
            out.push(val);
        }
        bars = out;

        if (isZero) {
            if (idleCounter < 90) { // ~3 seconds at 30 FPS
                idleCounter++;
            } else {
                pollTimer.interval = 500; // Slow down to 2 FPS when idle
            }
        } else {
            idleCounter = 0;
            pollTimer.interval = 33; // Full speed (30 FPS) when active
        }
    }

    Timer {
        id: pollTimer
        interval: 33
        running: vis.active
        repeat: true
        onTriggered: reader.read()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: feederLauncher.spawn()
    }

    function restart() {
        vis.idleCounter = 0;
        pollTimer.interval = 33;
        feederLauncher.killFeeder();
        restartTimer.start();
    }

    Timer {
        id: restartTimer
        interval: 150
        repeat: false
        onTriggered: feederLauncher.spawn()
    }

    Connections {
        target: plasmoid.configuration
        ignoreUnknownSignals: true
        function onNumBarsChanged() {
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
