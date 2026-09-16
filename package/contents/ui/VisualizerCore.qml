import QtQuick
import QtCore

Item {
    id: vis

    required property var configuration
    required property Component commandSourceComponent
    property string runtimeDirectory: ""

    property int numBars: configuration.numBars
    property real maxRange: 1000.0
    property var bars: Array(numBars).fill(0)
    property real frameTimeMs: 0
    // Settled audible tones still drive decorative motion. Keep the original
    // clock suppression for default styles and for settled silence.
    readonly property bool motionClockRequired: {
        const style = configuration.visualizerType ?? 0;
        return style === 6 || (!(configuration.reducedMotion ?? false) && ([9, 10, 11, 13, 14, 15].includes(style) || configuration.vizColorMode === "rainbow" || (configuration.hueReactive ?? false)));
    }
    // Normalized source energy, before display smoothing, mirroring or taper.
    readonly property real bass: analysis.bass
    readonly property real mid: analysis.mid
    readonly property real high: analysis.high
    readonly property real bassSmoothed: analysis.bassSmoothed
    // One accepted sample pulse; the first sample after a reset only primes it.
    readonly property bool attack: analysis.attack

    QtObject {
        id: analysis
        property real bass: 0
        property real mid: 0
        property real high: 0
        property real bassSmoothed: 0
        property bool attack: false
        property bool initialized: false
        property real lastSampleMs: 0
        property real lastAttackMs: -1
        property int generation: 0
    }

    function resetAnalysis() {
        analysis.generation++;
        analysis.bass = 0;
        analysis.mid = 0;
        analysis.high = 0;
        analysis.bassSmoothed = 0;
        analysis.attack = false;
        analysis.initialized = false;
        analysis.lastSampleMs = 0;
        analysis.lastAttackMs = -1;
    }

    // Fractional bins keep the 20/40/40 split meaningful with odd or tiny frames.
    // Each source bar is visited once, apart from the two shared boundary bins.
    function bandMean(parts, start, end) {
        let sum = 0;
        for (let i = Math.floor(start); i < Math.ceil(end); i++)
            sum += parts[i] * (Math.min(i + 1, end) - Math.max(i, start));
        return maxRange > 0 ? Math.max(0, Math.min(1, sum / (end - start) / maxRange)) : 0;
    }

    function analyzeFrame(parts, now) {
        const bassEnd = parts.length * 0.2;
        const midEnd = parts.length * 0.6;
        const nextBass = bandMean(parts, 0, bassEnd);
        const nextMid = bandMean(parts, bassEnd, midEnd);
        const nextHigh = bandMean(parts, midEnd, parts.length);
        // Treat a wall-clock correction like a new capture. A backwards jump
        // must not leave beat detection locked out until the old time returns.
        const primed = analysis.initialized && now >= analysis.lastSampleMs;
        let smoothed = nextBass;
        let onset = false;
        if (primed) {
            // Evolve the envelope over the time the previous sample was held.
            // This works at every configured frame rate and across duplicate
            // frames, whose INI timestamps are only whole-second heartbeats.
            const decay = Math.exp(-(now - analysis.lastSampleMs) / 150);
            smoothed = analysis.bass + (analysis.bassSmoothed - analysis.bass) * decay;
            if (Math.abs(smoothed - analysis.bass) <= 0.0005)
                smoothed = analysis.bass;
            const above = nextBass - smoothed > 0.12;
            const wasAbove = analysis.bass - smoothed > 0.12;
            onset = above && !wasAbove && (analysis.lastAttackMs < 0 || now - analysis.lastAttackMs >= 180);
        } else {
            analysis.lastAttackMs = -1;
        }
        if (onset)
            analysis.lastAttackMs = now;
        analysis.initialized = true;
        analysis.lastSampleMs = now;
        analysis.bass = nextBass;
        analysis.mid = nextMid;
        analysis.high = nextHigh;
        analysis.bassSmoothed = smoothed;
        analysis.attack = onset;
    }
    // Audio capture is independent of MPRIS: browsers and other apps can emit
    // sound without the selected media player reporting playback.
    property bool active: true
    // Enable only for a host with its own runtime directory. Plasma instances
    // share a feeder, so one hidden Plasma widget must not stop the others.
    property bool stopWhenInactive: false
    readonly property bool hasAudio: bars.some(value => value > idleThreshold)
    property int idleCounter: 0
    property bool restarting: false

    property bool plasmoidVisible: true

    readonly property string feederPath: Qt.resolvedUrl("../code/feeder.sh").toString().replace(/^file:\/\//, "")

    CommandSource {
        id: feederLauncher
        property string pendingRestart: ""
        property string ownedFeeder: ""
        property bool claimedRuntime: false
        sourceComponent: vis.commandSourceComponent
        onNewData: function (source, data) {
            disconnectSource(source);
            if (source === pendingRestart) {
                pendingRestart = "";
                if (vis.active && data["exit code"] === 0)
                    spawn();
            } else if (source === ownedFeeder) {
                ownedFeeder = "";
            }
        }
        function spawnCommand() {
            const args = [vis.configuration.numBars, vis.configuration.framerate, vis.configuration.sensitivity, vis.configuration.noiseReduction, vis.configuration.inputMethod || "auto"].join(" ");
            return "bash " + vis.shellQuote(vis.feederPath) + " " + args;
        }
        function spawn() {
            if (vis.stopWhenInactive) {
                if (!vis.active || pendingRestart)
                    return;
                // exec makes the tracked process the feeder itself, including
                // the interval before it has written its runtime PID file.
                ownedFeeder = "exec " + spawnCommand();
                connectSource(ownedFeeder, false, true);
            } else {
                connectSource(spawnCommand(), true);
            }
        }
        function cancelOwned() {
            const pending = pendingRestart;
            pendingRestart = "";
            if (pending)
                cancelSource(pending);
            const feeder = ownedFeeder;
            ownedFeeder = "";
            if (feeder)
                cancelSource(feeder);
        }
        // Stop the feeder by the PID it records once it holds the lock, so a
        // restart during a backend probe cannot carry on with the old settings.
        // -f spares a process that reused a stale PID. Older feeders write no
        // PID file; stopping their cava makes them exit too. Neither kill can
        // hit the shell running it.
        function killCommand() {
            if (!vis.resolvedRunDir)
                return "";
            const conf = (vis.resolvedRunDir + "/cava.conf").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
            return "pkill -F " + vis.shellQuote(vis.resolvedRunDir + "/feeder.pid") + " -f 'feeder\\.sh' 2>/dev/null; pkill -f -- " + vis.shellQuote("^([^ ]*/)?cava -p " + conf + "$");
        }
        function killFeeder() {
            if (vis.stopWhenInactive) {
                cancelOwned();
                if (claimedRuntime || !vis.resolvedRunDir)
                    return;
                claimedRuntime = true;
            }
            const command = killCommand();
            if (command)
                connectSource(command, true);
        }
        // Wait for the old feeder to release the lock rather than a fixed
        // delay, which lost the race whenever it was slow to exit.
        function restartFeeder() {
            let kill = killCommand();
            if (vis.stopWhenInactive) {
                cancelOwned();
                // Claim old ownerless jobs once. Our tracked feeder already
                // received SIGTERM; a second signal can interrupt its cleanup.
                if (claimedRuntime)
                    kill = "";
                claimedRuntime = true;
                // Return to QML after waiting. A detached shell must never
                // spawn a feeder after the view has become inactive.
                pendingRestart = (kill ? kill + "; " : "") + "mkdir -p " + vis.shellQuote(vis.resolvedRunDir) + "; exec flock -w 3 " + vis.shellQuote(vis.resolvedRunDir + "/lock") + " true";
                connectSource(pendingRestart);
                return;
            }
            connectSource(kill ? kill + "; flock -w 3 " + vis.shellQuote(vis.resolvedRunDir + "/lock") + " true; " + spawnCommand() : spawnCommand(), true);
        }
    }

    // Resolved at startup by pathResolver — no shell expansion needed after that.
    property string resolvedRunDir: ""
    // A dedicated host takes ownership of any feeder left by an earlier run.
    // Shared Plasma instances keep joining the existing feeder instead.
    onResolvedRunDirChanged: {
        if (stopWhenInactive && resolvedRunDir)
            restart();
    }
    readonly property string resolvedBarsPath: resolvedRunDir ? resolvedRunDir + "/bars" : ""
    readonly property string resolvedFramePath: resolvedRunDir ? resolvedRunDir + "/frame.ini" : ""
    readonly property string resolvedStatusPath: resolvedRunDir ? resolvedRunDir + "/status" : ""
    readonly property string resolvedStatusIniPath: resolvedRunDir ? resolvedRunDir + "/status.ini" : ""

    CommandSource {
        id: pathResolver
        sourceComponent: vis.commandSourceComponent
        onNewData: function (source, data) {
            disconnectSource(source);
            const p = (data["stdout"] || "").trim();
            if (p)
                vis.resolvedRunDir = p;
        }
    }

    Component.onCompleted: {
        // Resolve $XDG_RUNTIME_DIR once at startup so we can use the absolute path
        // without spawning a shell to expand variables on every frame.
        if (runtimeDirectory)
            resolvedRunDir = runtimeDirectory;
        else
            pathResolver.connectSource("echo -n ${XDG_RUNTIME_DIR:-/tmp}/audio-wave-widget");
    }

    // ── Backend health ────────────────────────────────────────────────────────
    // feeder.sh writes a one-line status file: "ok <method>", "probing <method>"
    // or "error <code> [detail]". Without it a broken cava is indistinguishable
    // from silence — the widget just draws a flat line forever, which is exactly
    // what users report as "the bars don't work".
    property string backendState: ""   // "" (unknown) | "ok" | "probing" | "error"
    property string backendCode: ""    // no-cava | no-backend | cava-exited
    property string backendDetail: ""
    property int backendErrorStreak: 0

    // cava exiting is usually transient (sound server restart, sink switch) and
    // the respawn below fixes it within seconds, so only complain once it has
    // clearly stuck. A missing cava or no usable backend is reported right away.
    readonly property bool backendFailed: backendState === "error" && (backendCode !== "cava-exited" || backendErrorStreak >= 3)

    readonly property string backendMessage: {
        if (!backendFailed)
            return "";
        if (backendCode === "no-cava")
            return "cava is not installed";
        if (backendCode === "no-backend")
            return "No usable audio input (tried " + backendDetail.replace(/,/g, ", ") + ")";
        return "Audio capture stopped";
    }

    // The install command for whatever package manager feeder.sh found. Naming
    // the command is the whole point — "cava is not installed" on its own is
    // what sends people to the issue tracker.
    readonly property string installCommand: {
        switch (backendDetail) {
        case "apt-get":
            return "sudo apt install cava";
        case "dnf":
            return "sudo dnf install cava";
        case "pacman":
            return "sudo pacman -S cava";
        case "zypper":
            return "sudo zypper install cava";
        case "apk":
            return "sudo apk add cava";
        case "xbps-install":
            return "sudo xbps-install cava";
        case "emerge":
            return "sudo emerge media-sound/cava";
        case "nix-env":
            return "add pkgs.cava to your configuration";
        default:
            return "install the 'cava' package";
        }
    }

    // Second line under the headline: short enough for a 44px tall waveform.
    readonly property string backendAction: {
        if (!backendFailed)
            return "";
        if (backendCode === "no-cava")
            return installCommand;
        if (backendCode === "no-backend")
            return "is PipeWire or PulseAudio running?";
        return "see " + vis.resolvedRunDir + "/cava.log";
    }

    readonly property string backendHint: {
        if (!backendFailed)
            return "";
        if (backendCode === "no-cava")
            return installCommand + "\nThe widget picks it up within 30 seconds — no restart needed, unless your package manager only changes PATH for new sessions.";
        if (backendCode === "no-backend")
            return "cava could not capture from any backend. Check that PipeWire or PulseAudio is running, or pin one under Audio Input in the widget settings.";
        return "cava keeps exiting — see " + vis.resolvedRunDir + "/cava.log";
    }

    CommandSource {
        id: statusReader
        sourceComponent: vis.commandSourceComponent
        onNewData: function (source, data) {
            disconnectSource(source);
            vis.handleStatus((data["stdout"] || "").trim());
        }
        function read() {
            if (vis.resolvedStatusPath && connectedSources.length === 0)
                connectSource("cat " + vis.shellQuote(vis.resolvedStatusPath));
        }
    }

    Loader {
        id: statusSource
        active: vis.resolvedStatusIniPath !== ""
        sourceComponent: Settings {
            location: "file://" + vis.resolvedStatusIniPath
        }
    }

    function readStatus() {
        const frame = barsSource.item as Settings;
        const status = statusSource.item as Settings;
        if (frame && status) {
            frame.sync();
            // Old feeders can take over the shared lock. Only trust their
            // predecessor's status.ini while a current feeder refreshes frames.
            const stamp = Number(frame.value("t", 0)) * 1000;
            if (Number(frame.value("protocol", 0)) >= 2 && Math.abs(Date.now() - stamp) < 2000) {
                status.sync();
                const line = status.value("v", "");
                if (line) {
                    handleStatus(line);
                    return;
                }
            }
        }
        statusReader.read();
    }

    function handleStatus(line) {
        // No status file at all (feeder never ran, or an older one is still
        // holding the lock): stay quiet rather than guess.
        if (!line)
            return;
        const parts = line.split(" ");
        backendState = parts[0] || "";
        backendCode = parts[1] || "";
        backendDetail = parts[2] || "";
        if (backendState === "error") {
            backendErrorStreak++;
            // A backend that worked and died usually comes straight back, so
            // nudge the feeder instead of waiting out the 30s heartbeat. The
            // flock in feeder.sh makes this a no-op if it is already healthy.
            // Hard failures (no cava, no backend at all) are left to the
            // heartbeat — respawning every 4s would never fix them.
            if (backendCode === "cava-exited" && vis.active)
                feederLauncher.spawn();
        } else {
            backendErrorStreak = 0;
        }
    }

    Timer {
        interval: 4000
        running: vis.plasmoidVisible && vis.active && vis.resolvedStatusPath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: vis.readStatus()
    }

    // ── Frame transport ───────────────────────────────────────────────────────
    // New feeders publish a separate INI frame for in-process reads. Keep the
    // original semicolon file usable by older widgets sharing this feeder.
    // A timestamp detects a stale INI file if an older feeder takes over later.
    Loader {
        id: barsSource
        active: vis.resolvedFramePath !== ""
        sourceComponent: Settings {
            location: "file://" + vis.resolvedFramePath
        }
    }

    function shellQuote(value) {
        return "'" + value.replace(/'/g, "'\\''") + "'";
    }

    CommandSource {
        id: legacyReader
        property int analysisGeneration: 0
        sourceComponent: vis.commandSourceComponent
        onNewData: function (source, data) {
            disconnectSource(source);
            // A slow read from before hiding/restarting capture is obsolete.
            if (analysisGeneration !== analysis.generation)
                return;
            if (!vis.handleData((data["stdout"] || "").trim()))
                vis.updatePollingCadence(true);
        }
        function read() {
            if (vis.resolvedBarsPath && connectedSources.length === 0) {
                analysisGeneration = analysis.generation;
                connectSource("cat " + vis.shellQuote(vis.resolvedBarsPath));
            }
        }
    }

    property real lastIniFrame: 0

    function readBars() {
        const s = barsSource.item as Settings;
        if (!s) {
            updatePollingCadence(true);
            return;
        }
        s.sync();
        const now = Date.now();
        const stamp = Number(s.value("t", 0)) * 1000;
        if (stamp > 0 && Math.abs(now - stamp) < 2000) {
            lastIniFrame = now;
            if (!handleData(s.value("v", "")))
                updatePollingCadence(true);
        } else if (now - lastIniFrame >= 2000) {
            // Join an already-running old feeder without killing it. This
            // fallback goes away as soon as a current feeder owns the lock.
            legacyReader.read();
        } else {
            // The poll landed between truncating and writing the frame: keep
            // the previous bars, as for an empty legacy read.
            updatePollingCadence(true);
        }
    }

    // Battery saver (set by the host while on battery): draw at most 20 Hz.
    property bool batterySaverActive: false
    readonly property int pollInterval: Math.round(1000 / (batterySaverActive ? Math.min(20, vis.configuration.framerate) : vis.configuration.framerate))

    // Exponential moving average toward each new cava frame. Cava already
    // smooths over time, but reading a fresh frame every poll still snaps
    // visibly; blending softens the motion without adding latency you'd notice.
    // 0 = frozen, 1 = no smoothing (raw snap). ~0.55 reads as fluid.
    readonly property real smoothing: 0.55

    // Treat the bottom slice of the range as silence. Cava's noise floor and
    // residual smoothing leave tiny non-zero values even when nothing plays, so
    // a strict `val > 0` idle test never trips. Anything under this is "quiet".
    readonly property real idleThreshold: maxRange * 0.012

    function updatePollingCadence(isQuiet) {
        if (restarting) {
            pollTimer.interval = vis.pollInterval;
        } else if (isQuiet) {
            if (idleCounter < vis.configuration.framerate * 3) {
                idleCounter++;
            } else {
                pollTimer.interval = 500;
            }
        } else {
            idleCounter = 0;
            pollTimer.interval = vis.pollInterval;
        }
    }

    // Accept both the INI string list and the original semicolon transport.
    // Empty or malformed reads keep the previous frame and return false. Bars
    // that have settled are not reassigned, so silence emits no barsChanged.
    function handleData(frame, timestampMs = Date.now()) {
        if (!frame)
            return false;
        const rawParts = typeof frame === "string" ? frame.replace(/^v=/, "").split(/[;,]/) : frame;
        const parts = [];
        for (let i = 0; i < rawParts.length; i++) {
            if (rawParts[i] === "")
                continue;
            const value = Number(rawParts[i]);
            if (!isFinite(value))
                return false;
            const v = Math.max(0, Math.min(maxRange, value));
            parts.push(v > idleThreshold ? v : 0);
        }
        if (!parts.length)
            return false;
        // Publish analysis before bars/frameTimeMs notify rendering consumers.
        // Invalid frames return above without changing either kind of state.
        analyzeFrame(parts, timestampMs);
        const count = numBars;
        const prev = bars;
        const out = new Array(count);
        let changed = prev.length !== count;
        let isQuiet = true;
        for (let i = 0; i < count; i++) {
            // Keep animating even if the feeder is briefly still on the old bar
            // count while cava restarts after a config change.
            const target = parts[Math.min(parts.length - 1, Math.floor(i * parts.length / count))];
            isQuiet = isQuiet && target === 0;
            const p = prev[i] || 0;
            const blended = p + smoothing * (target - p);
            const next = Math.abs(blended - target) < 0.5 ? target : blended;
            out[i] = next;
            changed = changed || next !== p;
        }
        updatePollingCadence(isQuiet);
        if (changed)
            bars = out;
        if (changed || (!isQuiet && motionClockRequired))
            frameTimeMs = timestampMs;
        return true;
    }

    Timer {
        id: pollTimer
        objectName: "framePollTimer"
        interval: vis.pollInterval
        running: vis.active && vis.plasmoidVisible && !vis.backendFailed && vis.resolvedFramePath !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: vis.readBars()
    }

    onActiveChanged: {
        resetAnalysis();
        if (active) {
            idleCounter = 0;
            pollTimer.interval = pollInterval;
            if (stopWhenInactive && resolvedRunDir)
                restart();
        } else if (stopWhenInactive) {
            configurationRestart.stop();
            lastIniFrame = 0;
            backendState = "";
            feederLauncher.killFeeder();
        }
    }

    onPlasmoidVisibleChanged: {
        resetAnalysis();
        if (plasmoidVisible) {
            idleCounter = 0;
            pollTimer.interval = pollInterval;
        }
    }

    onBackendFailedChanged: {
        resetAnalysis();
        if (!backendFailed) {
            idleCounter = 0;
            pollTimer.interval = pollInterval;
        }
    }

    // Keep the feeder alive. spawn() is guarded by flock in feeder.sh, so a
    // re-spawn while cava is healthy is a cheap no-op (it exits immediately).
    // We still avoid hammering it: fire once on start to get cava up fast, then
    // fall back to a slow 30s heartbeat that recovers from a crashed feeder.
    Timer {
        objectName: "feederHeartbeat"
        interval: 30000
        running: vis.plasmoidVisible && vis.active && vis.resolvedRunDir !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Fresh native frames already prove that the feeder is alive.
            if (vis.backendState !== "ok" || Date.now() - vis.lastIniFrame >= 2000)
                feederLauncher.spawn();
        }
    }

    function restart() {
        configurationRestart.stop();
        resetAnalysis();
        if (stopWhenInactive && !active) {
            feederLauncher.killFeeder();
            return;
        }
        vis.restarting = true;
        vis.idleCounter = 0;
        vis.backendErrorStreak = 0;
        vis.bars = Array(vis.numBars).fill(0);
        pollTimer.interval = vis.pollInterval;
        feederLauncher.restartFeeder();
        restartCooldown.restart();
    }

    Timer {
        id: restartCooldown
        interval: 1200
        repeat: false
        onTriggered: vis.restarting = false
    }

    Connections {
        target: vis.configuration
        ignoreUnknownSignals: true
        function onNumBarsChanged() {
            configurationRestart.restart();
        }
        function onSensitivityChanged() {
            configurationRestart.restart();
        }
        function onFramerateChanged() {
            configurationRestart.restart();
        }
        function onNoiseReductionChanged() {
            configurationRestart.restart();
        }
        function onInputMethodChanged() {
            configurationRestart.restart();
        }
    }

    // Applying several settings (or dragging a slider) needs one restart with
    // the final values, rather than a competing shell/backend for each signal.
    Timer {
        id: configurationRestart
        interval: 100
        repeat: false
        onTriggered: vis.restart()
    }

    Component.onDestruction: feederLauncher.killFeeder()
}
