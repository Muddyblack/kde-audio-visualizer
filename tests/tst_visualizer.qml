import QtQuick
import QtTest
import QtCore
import org.kde.plasma.plasma5support as Support
import "../package/contents/ui"

TestCase {
    name: "Visualizer"
    when: windowShown
    property QtObject plasmoid: QtObject {
        property bool visible: false
        property QtObject configuration: QtObject {
            property int numBars: 4
            property int framerate: 60
            property int sensitivity: 100
            property real noiseReduction: 0.77
            property string inputMethod: "auto"
        }
    }
    property string runtimeDir: StandardPaths.writableLocation(StandardPaths.RuntimeLocation).toString().replace(/^file:\/\//, "")
    Component {
        id: visualizer
        Visualizer {}
    }
    // Hands commands captured from the stub to run.py, which executes them.
    Settings {
        id: exported
        location: "file://" + runtimeDir + "/commands.ini"
    }
    property var subject: null
    property int updates: 0
    property int bandUpdates: 0
    property int attacks: 0
    Connections {
        target: subject
        function onBarsChanged() {
            updates++;
        }
        function onBassChanged() {
            bandUpdates++;
        }
        function onMidChanged() {
            bandUpdates++;
        }
        function onHighChanged() {
            bandUpdates++;
        }
        function onBassSmoothedChanged() {
            bandUpdates++;
        }
        function onAttackChanged() {
            bandUpdates++;
            if (subject.attack)
                attacks++;
        }
    }

    function init() {
        Support.Commands.calls = [];
        Support.Commands.cancelled = [];
        Support.Commands.legacyFrame = "100;200;300;400;";
        plasmoid.visible = false;
        subject = createTemporaryObject(visualizer, this);
        verify(subject !== null);
        updates = 0;
        bandUpdates = 0;
        attacks = 0;
    }

    function test_legacyAndIniFrames() {
        subject.handleData("100;200;300;400;");
        verify(subject.hasAudio);
        compare(subject.bars.length, 4);
        verify(subject.bars[3] > subject.bars[0]);
        subject.handleData(["400", "300", "200", "100", ""]);
        verify(subject.hasAudio);
        const before = subject.bars.slice();
        subject.handleData("");
        subject.handleData(["invalid", "200"]);
        compare(subject.bars, before);
    }

    function test_silenceSettlesAndAudioWakes() {
        const started = Date.now();
        subject.handleData("900;900;900;900;", started);
        verify(subject.hasAudio);
        for (let i = 0; i < 200; i++)
            subject.handleData("0;1;2;0;", started + (i + 1) * 17);
        verify(!subject.hasAudio);
        compare(subject.bars, [0, 0, 0, 0]);
        compare(subject.bass, 0);
        compare(subject.mid, 0);
        compare(subject.high, 0);
        compare(subject.bassSmoothed, 0);
        verify(!subject.attack);
        const settled = updates;
        const settledBands = bandUpdates;
        for (let i = 0; i < 20; i++)
            subject.handleData("0;0;0;0;", started + (i + 201) * 17);
        compare(updates, settled, "Silent polls must not repaint the wave");
        compare(bandUpdates, settledBands, "Silent polls must not animate band consumers");
        subject.handleData("900;900;900;900;", started + 221 * 17);
        verify(subject.hasAudio, "Audio must wake the wave without a media player");
        verify(updates > settled);
        verify(subject.bass > 0 && subject.mid > 0 && subject.high > 0, "Audio must wake every band consumer");
        verify(bandUpdates > settledBands);
    }

    function test_repeatedFramesSmoothThenSettle() {
        const frame = "900;900;900;900;";
        verify(subject.handleData(frame));
        compare(subject.bars, [495, 495, 495, 495]);
        subject.handleData(frame);
        verify(subject.bars[0] > 495 && subject.bars[0] < 900, "Repeated source frames must still animate toward their target");
        for (let i = 0; i < 20; i++)
            subject.handleData(frame);
        compare(subject.bars, [900, 900, 900, 900]);
        const settled = updates;
        for (let i = 0; i < 20; i++)
            subject.handleData(frame);
        compare(updates, settled, "Settled frames must not emit barsChanged");
        subject.restart();
        compare(subject.bass, 0, "Restart must clear the previous bass energy");
        compare(subject.mid, 0);
        compare(subject.high, 0);
        compare(subject.bassSmoothed, 0, "Restart must clear the onset baseline");
        verify(!subject.attack);
        subject.handleData(frame);
        compare(subject.bars, [495, 495, 495, 495], "Restart must smooth from zero again");
    }

    function test_listFramesAndMalformedFramesRecover() {
        verify(subject.handleData(["100", "200", ""]));
        compare(subject.bars, [55, 55, 110, 110]);
        const before = subject.bars.slice();
        verify(!subject.handleData(["300", "invalid"]));
        compare(subject.bars, before);
        verify(subject.handleData("1000;1000;1000;1000;"));
        verify(subject.bars[0] > before[0], "A malformed frame must not poison the next valid frame");
    }

    function test_missingFramesBackOffAndVisibilityResumes() {
        subject.resolvedRunDir = runtimeDir + "/missing-feeder";
        Support.Commands.legacyFrame = "";
        const polling = findChild(subject, "framePollTimer");
        verify(polling !== null);
        for (let i = 0; i < 200; i++)
            subject.readBars();
        compare(polling.interval, 500, "A failed or missing feeder must not cause full-rate polling forever");
        subject.active = false;
        subject.active = true;
        compare(polling.interval, subject.pollInterval, "Resuming must restore the requested frame rate");
        for (let i = 0; i < 200; i++)
            subject.readBars();
        compare(polling.interval, 500);
        plasmoid.visible = true;
        compare(polling.interval, subject.pollInterval, "Becoming visible must not retain the idle delay");
    }

    function test_oldFeederFallback() {
        subject.resolvedRunDir = runtimeDir + "/old-feeder";
        subject.readBars();
        verify(subject.hasAudio);
        verify(Support.Commands.calls.some(value => value.startsWith("cat ")));
    }

    function test_backendFailureStopsFramePollsAndRecoveryResumes() {
        subject.resolvedRunDir = runtimeDir + "/missing-feeder";
        Support.Commands.legacyFrame = "";
        plasmoid.visible = true;
        wait(20);
        const polling = findChild(subject, "framePollTimer");
        verify(polling.running);
        for (let i = 0; i < 200; i++)
            subject.readBars();
        compare(polling.interval, 500);
        subject.handleStatus("error no-cava apt-get");
        verify(subject.backendFailed);
        verify(!polling.running, "A known failed backend must stop frame polling entirely");
        const calls = Support.Commands.calls.length;
        wait(100);
        compare(Support.Commands.calls.length, calls, "Failed capture must not keep launching frame readers");
        subject.handleStatus("ok pipewire");
        verify(!subject.backendFailed);
        verify(polling.running);
        compare(polling.interval, subject.pollInterval, "Recovery must immediately restore the requested frame rate");
    }

    function test_liveFeederWithoutFrameProcesses() {
        subject.resolvedRunDir = runtimeDir + "/audio-wave-widget";
        let sawLow = false;
        let sawHigh = false;
        let sawLowBars = false;
        let sawHighBars = false;
        const calls = Support.Commands.calls.length;
        for (let i = 0; i < 90; i++) {
            subject.readBars();
            // The synthetic cava sends the same 100/900 value to every bar.
            // All three frequency bands must track that shared frame.
            for (const name of ["bass", "mid", "high"]) {
                verify(isFinite(subject[name]) && subject[name] >= 0 && subject[name] <= 1, name + " must stay normalized");
                fuzzyCompare(subject[name], subject.bass, 1e-6, name + " must share the uniform source energy");
            }
            const low = Math.abs(subject.bass - 0.1) < 1e-6;
            const high = Math.abs(subject.bass - 0.9) < 1e-6;
            if (subject.hasAudio)
                verify(low || high, "Band energy must preserve the normalized 100/900 source values before visual smoothing");
            sawLow = sawLow || low;
            sawHigh = sawHigh || high;
            sawLowBars = sawLowBars || subject.bars[0] < 200;
            sawHighBars = sawHighBars || subject.bars[0] > 700;
            wait(20);
        }
        verify(sawLow && sawHigh, "Bands must follow changing external frames");
        verify(sawLowBars && sawHighBars, "Rendered bars must follow changing external frames");
        verify(attacks > 0, "Live bass transitions must produce attacks");
        verify(subject.hasAudio);
        compare(Support.Commands.calls.length, calls, "Frame and band updates must not launch processes");
        verify(!Support.Commands.calls.some(value => value.startsWith("cat ")), "Current feeder must use in-process reads");
        subject.readStatus();
        compare(subject.backendState, "ok");
        verify(!Support.Commands.calls.some(value => value.startsWith("cat ")), "Current feeder status must use in-process reads too");
        const heartbeat = findChild(subject, "feederHeartbeat");
        verify(heartbeat !== null);
        heartbeat.triggered();
        verify(!Support.Commands.calls.some(value => value.startsWith("bash ")), "Fresh healthy frames must avoid redundant feeder launches");
        subject.lastIniFrame = Date.now() - 3000;
        heartbeat.triggered();
        verify(Support.Commands.calls.some(value => value.startsWith("bash ")), "Stale frames must still restart a crashed feeder");
    }

    function test_configurationChangesRestartOnceWithFinalValues() {
        const config = plasmoid.configuration;
        subject.resolvedRunDir = runtimeDir + "/audio-wave-widget";
        try {
            config.sensitivity = 110;
            config.framerate = 30;
            config.noiseReduction = 0.5;
            wait(50);
            config.numBars = 6;
            config.inputMethod = "pulse";
            wait(70);
            compare(Support.Commands.calls.filter(value => value.includes("pkill")).length, 0);
            wait(60);
            const restarts = Support.Commands.calls.filter(value => value.includes("pkill"));
            compare(restarts.length, 1, "A burst of settings must launch one backend restart");
            verify(restarts[0].includes(" 6 30 110 0.5 pulse"), "The restart must use all final settings");
        } finally {
            config.numBars = 4;
            config.framerate = 60;
            config.sensitivity = 100;
            config.noiseReduction = 0.77;
            config.inputMethod = "auto";
        }
    }

    // run.py runs this command against a real feeder stuck in a backend probe.
    function test_restartStopsFeederBeforeSpawning() {
        subject.resolvedRunDir = runtimeDir + "/audio-wave-widget";
        subject.restart();
        const restart = Support.Commands.calls.find(value => value.includes("pkill"));
        verify(restart !== undefined);
        verify(restart.indexOf("pkill") < restart.indexOf("flock -w") && restart.indexOf("flock -w") < restart.indexOf("bash "), restart);
        // Base64 keeps quotes and backslashes out of QSettings' INI escaping.
        exported.setValue("restart", Qt.btoa(restart).replace(/=+$/, ""));
        exported.sync();
    }

    function test_secondInstanceJoinsWithoutRestarting() {
        plasmoid.visible = true;
        const other = createTemporaryObject(visualizer, this);
        verify(other !== null);
        // The command stub does not execute the asynchronous path resolver.
        other.resolvedRunDir = runtimeDir + "/audio-wave-widget";
        wait(50);
        verify(Support.Commands.calls.some(value => value.startsWith("bash ")));
        verify(!Support.Commands.calls.some(value => value.includes("pkill")));
        subject.active = false;
        wait(50);
        verify(other.active);
        verify(!Support.Commands.calls.some(value => value.includes("pkill")));
    }

    function test_dedicatedHostStopsCaptureWhenHidden() {
        subject.stopWhenInactive = true;
        subject.resolvedRunDir = runtimeDir + "/dedicated-feeder";
        verify(Support.Commands.calls.some(value => value.includes("flock -w")), "Dedicated startup must reclaim an old feeder");
        Support.Commands.calls = [];
        subject.active = false;
        verify(Support.Commands.cancelled.some(value => value.includes("flock -w")), "Hiding all views must cancel the pending capture restart");
        verify(!findChild(subject, "framePollTimer").running);
        verify(!findChild(subject, "feederHeartbeat").running);
        subject.restart();
        verify(!Support.Commands.calls.some(value => value.includes("bash ")), "Settings changes while hidden must not start capture");
        Support.Commands.calls = [];
        subject.active = true;
        verify(Support.Commands.calls.some(value => value.includes("flock -w")), "Uncovering a view must restart capture");
    }

    function test_sharedHostDoesNotStopOtherWidgetsWhenHidden() {
        subject.resolvedRunDir = runtimeDir + "/audio-wave-widget";
        subject.active = false;
        verify(!Support.Commands.calls.some(value => value.includes("pkill")), "A hidden Plasma view must preserve the shared capture");
    }
}
