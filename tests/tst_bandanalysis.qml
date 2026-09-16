import QtQuick
import QtTest
import org.kde.plasma.plasma5support as Support
import "../package/contents/ui"

TestCase {
    name: "BandAnalysis"
    when: windowShown

    Component {
        id: coreComponent
        VisualizerCore {
            active: false
            visible: false
            plasmoidVisible: false
            configuration: QtObject {
                property int numBars: 4
                property int framerate: 60
                property int sensitivity: 100
                property real noiseReduction: 0.77
                property string inputMethod: "auto"
                property int visualizerType: 0
                property bool reducedMotion: false
                property string vizColorMode: "solid"
                property bool hueReactive: false
            }
            commandSourceComponent: Component {
                Support.DataSource {}
            }
        }
    }

    property var subject
    property var deferredRead: null

    Component {
        id: deferredSourceComponent
        QtObject {
            id: deferredSource
            property var connectedSources: []
            signal newData(string source, var data)
            function connectSource(source) {
                if (source.startsWith("cat ")) {
                    connectedSources = connectedSources.concat([source]);
                    deferredRead = {
                        source: source,
                        emitter: deferredSource
                    };
                }
            }
            function disconnectSource(source) {
                connectedSources = connectedSources.filter(value => value !== source);
            }
        }
    }

    function init() {
        Support.Commands.calls = [];
        Support.Commands.cancelled = [];
        deferredRead = null;
        subject = createTemporaryObject(coreComponent, this);
        verify(subject !== null);
    }

    function compareBands(core, bass, mid, high) {
        fuzzyCompare(core.bass, bass, 1e-9, "Bass energy");
        fuzzyCompare(core.mid, mid, 1e-9, "Mid energy");
        fuzzyCompare(core.high, high, 1e-9, "High energy");
    }

    function compareCleared(core) {
        compareBands(core, 0, 0, 0);
        compare(core.bassSmoothed, 0);
        verify(!core.attack);
    }

    function sample(bass, timestamp, core) {
        const target = core || subject;
        verify(target.handleData([bass, 0, 0, 0, 0], timestamp));
    }

    function test_settledToneKeepsOnlyRequestedMotionClockRunning() {
        subject.bars = [500, 500, 500, 500];
        subject.handleData(subject.bars, 1000);
        compare(subject.frameTimeMs, 0, "Default renderer suppresses identical frames");
        for (const style of [6, 9, 10, 11, 13, 14, 15]) {
            subject.configuration.visualizerType = style;
            subject.handleData(subject.bars, 1000 + style);
            compare(subject.frameTimeMs, 1000 + style);
        }
        subject.configuration.visualizerType = 0;
        subject.configuration.vizColorMode = "rainbow";
        subject.handleData(subject.bars, 2000);
        compare(subject.frameTimeMs, 2000);
        subject.configuration.reducedMotion = true;
        subject.handleData(subject.bars, 2100);
        compare(subject.frameTimeMs, 2000, "Reduced motion freezes hue drift");
        subject.configuration.reducedMotion = false;
        subject.configuration.vizColorMode = "solid";
        subject.configuration.hueReactive = true;
        subject.handleData(subject.bars, 2200);
        compare(subject.frameTimeMs, 2200);
        subject.bars = [0, 0, 0, 0];
        subject.handleData(subject.bars, 2300);
        compare(subject.frameTimeMs, 2200, "Settled silence never advances decoration");
    }

    function test_initialStateAndFirstFramePrimesEnvelope() {
        compareCleared(subject);
        verify(subject.handleData("1000;300;500;600;800;", 1000));
        compareBands(subject, 1, 0.4, 0.7);
        compare(subject.bassSmoothed, 1);
        verify(!subject.attack, "Joining existing audio must not manufacture an attack");
    }

    function test_fractionalBands_data() {
        return [
            {
                tag: "one-bin",
                frame: [725],
                bass: 0.725,
                mid: 0.725,
                high: 0.725
            },
            {
                tag: "two-bins",
                frame: [100, 900],
                bass: 0.1,
                mid: 0.3,
                high: 0.9
            },
            {
                tag: "three-bins",
                frame: [100, 400, 1000],
                bass: 0.1,
                mid: 0.3,
                high: 0.9
            },
            {
                tag: "five-exact-bins",
                frame: [100, 200, 400, 800, 1000],
                bass: 0.1,
                mid: 0.3,
                high: 0.9
            },
            {
                tag: "seven-bins",
                frame: [100, 200, 300, 400, 500, 600, 700],
                bass: 0.1285714285714286,
                mid: 0.3285714285714286,
                high: 0.6071428571428571
            },
            {
                tag: "ten-exact-bins",
                frame: [100, 300, 400, 400, 400, 400, 800, 800, 800, 800],
                bass: 0.2,
                mid: 0.4,
                high: 0.8
            }
        ];
    }

    function test_fractionalBands(data) {
        verify(subject.handleData(data.frame, 1000));
        compareBands(subject, data.bass, data.mid, data.high);
    }

    function test_uniformBands_data() {
        const rows = [];
        for (const count of [1, 2, 3, 7, 64]) {
            for (const value of [-100, 0, 12, 13, 500, 1000, 1500]) {
                rows.push({
                    tag: count + "-bins-value-" + value,
                    frame: Array(count).fill(value),
                    expected: value <= 12 ? 0 : Math.min(value, 1000) / 1000
                });
            }
        }
        return rows;
    }

    function test_uniformBands(data) {
        verify(subject.handleData(data.frame, 1000));
        compareBands(subject, data.expected, data.expected, data.expected);
    }

    function test_clampsAndNoiseGatesBeforeAveraging() {
        verify(subject.handleData([0, 12, 13, 1001, -9], 1000));
        compareBands(subject, 0, 0.0065, 0.5);
    }

    function test_displayCountDoesNotChangeSourceBands() {
        const frame = [100, 200, 400, 800, 1000];
        for (const count of [1, 2, 4, 7, 64]) {
            const core = createTemporaryObject(coreComponent, this, {
                numBars: count
            });
            verify(core !== null);
            verify(core.handleData(frame, 1000));
            compare(core.bars.length, count);
            compareBands(core, 0.1, 0.3, 0.9);
        }
    }

    function test_bandEnergyPrecedesDisplaySmoothing() {
        sample(0, 1000);
        sample(1000, 1016);
        compare(subject.bass, 1);
        compare(subject.bars[0], 550, "The existing rendered bars retain their smoothing");
        compare(subject.bassSmoothed, 0, "The slow envelope describes the preceding audio");
        verify(subject.attack);
        sample(0, 1032);
        compare(subject.bass, 0, "The raw band must immediately release on silence");
        verify(subject.bars[0] > 0, "Rendered bars still fade out");
    }

    function test_stringAndListTransportsAgree() {
        const other = createTemporaryObject(coreComponent, this);
        verify(other !== null);
        verify(subject.handleData("v=100;200;400;800;1000;", 1000));
        verify(other.handleData(["100", "200", "400", "800", "1000", ""], 1000));
        compareBands(other, subject.bass, subject.mid, subject.high);
        verify(subject.handleData("v=100,200,400,800,1000,", 1016));
        compareBands(subject, 0.1, 0.3, 0.9);
    }

    function test_invalidFramesPreserveEntireState() {
        const control = createTemporaryObject(coreComponent, this);
        verify(control !== null);
        for (const core of [subject, control]) {
            sample(0, 1000, core);
            sample(1000, 1016, core);
            verify(core.attack);
        }
        const previousBars = subject.bars.slice();
        const previousTime = subject.frameTimeMs;
        const previousIdleCounter = subject.idleCounter;
        for (const frame of [undefined, null, "", [], ["", ""], "v=", "1;broken;3;", [1000, NaN], [1000, Infinity]]) {
            verify(!subject.handleData(frame, 5000), "Malformed data must be rejected atomically");
            compareBands(subject, 1, 0, 0);
            compare(subject.bassSmoothed, 0);
            verify(subject.attack, "Rejected frames must not consume the attack pulse");
            compare(subject.bars, previousBars);
            compare(subject.frameTimeMs, previousTime);
            compare(subject.idleCounter, previousIdleCounter);
        }
        sample(1000, 1048);
        sample(1000, 1048, control);
        compare(subject.bassSmoothed, control.bassSmoothed, "Rejected timestamps must not advance the envelope");
        compare(subject.attack, control.attack);
    }

    function test_midAndHighChangesDoNotTriggerBassAttacks() {
        sample(0, 1000);
        verify(subject.handleData([0, 1000, 1000, 0, 0], 1100));
        compareBands(subject, 0, 1, 0);
        verify(!subject.attack);
        verify(subject.handleData([0, 0, 0, 1000, 1000], 1200));
        compareBands(subject, 0, 0, 1);
        verify(!subject.attack);
        compare(subject.bassSmoothed, 0);
        sample(1000, 1300);
        verify(subject.attack, "A bass onset must trigger after unrelated frequency changes");
    }

    function test_attackThresholdIsStrict() {
        sample(0, 1000);
        sample(120, 1000);
        verify(!subject.attack, "Exactly the threshold is not an onset");
        sample(121, 1000);
        verify(subject.attack, "Crossing the threshold creates one pulse");
    }

    function test_duplicateFrameClearsPulseWithoutRetrigger() {
        sample(0, 1000);
        sample(1000, 1010);
        verify(subject.attack);
        sample(1000, 1010);
        verify(!subject.attack, "Even a duplicate sample must clear the pulse");
        sample(1000, 1600);
        verify(!subject.attack, "A sustained bass value is not a fresh onset");
    }

    function test_repeatedBeatsRespectCooldown() {
        sample(0, 1000);
        sample(1000, 1010);
        verify(subject.attack);
        sample(0, 1020);
        sample(1000, 1100);
        verify(!subject.attack, "Beats inside the 180 ms refractory period are suppressed");
        sample(0, 1101);
        sample(1000, 1189);
        verify(!subject.attack, "The cooldown includes 179 ms");
        sample(0, 1189);
        sample(1000, 1190);
        verify(subject.attack, "A new crossing at 180 ms can produce an attack");
    }

    function test_gradualRisingBeatCrossesEnvelopeThreshold() {
        sample(0, 1000);
        sample(50, 1016);
        verify(!subject.attack);
        sample(100, 1032);
        verify(!subject.attack);
        sample(150, 1048);
        verify(subject.attack, "Several small rises can accumulate into a bass onset");
    }

    function test_steadyToneDoesNotRetriggerAtSlowPollingRates_data() {
        return [
            {
                tag: "two-fps",
                step: 500
            },
            {
                tag: "one-fps",
                step: 1000
            }
        ];
    }

    function test_steadyToneDoesNotRetriggerAtSlowPollingRates(data) {
        sample(0, 1000);
        sample(1000, 1000 + data.step);
        verify(subject.attack);
        for (let i = 2; i < 10; i++) {
            sample(1000, 1000 + data.step * i);
            verify(!subject.attack, "A steady tone must not become repeated beats at a low polling rate");
        }
        compare(subject.bassSmoothed, 1, "The envelope eventually snaps to a settled target");
    }

    function test_envelopeDependsOnElapsedTimeRatherThanPollCount() {
        const subdivided = createTemporaryObject(coreComponent, this);
        verify(subdivided !== null);
        for (const core of [subject, subdivided]) {
            sample(0, 1000, core);
            sample(1000, 1010, core);
        }
        sample(1000, 1310);
        for (let time = 1060; time <= 1310; time += 50)
            sample(1000, time, subdivided);
        fuzzyCompare(subject.bassSmoothed, subdivided.bassSmoothed, 1e-9, "Equal durations at a constant level must have the same envelope");
        fuzzyCompare(subject.bassSmoothed, 0.8646647167633873, 1e-9, "The envelope reaches about 86.5 percent after 300 ms");
        verify(!subject.attack);
        verify(!subdivided.attack);
    }

    function test_silenceEnvelopeSettlesToExactZero() {
        sample(1000, 1000);
        sample(0, 1016);
        for (let time = 1066; time <= 3016; time += 50)
            sample(0, time);
        compareCleared(subject);
    }

    function test_backwardsClockReprimesAndReleasesCooldown() {
        sample(0, 1000);
        sample(1000, 1010);
        verify(subject.attack);
        sample(1000, 100);
        compare(subject.bassSmoothed, 1);
        verify(!subject.attack, "A clock correction must establish a new baseline");
        sample(0, 110);
        sample(1000, 300);
        verify(subject.attack, "An old clock value must not lock out subsequent beats");
    }

    function test_restartClearsBandsAndPrimesNextFrame() {
        sample(0, 1000);
        sample(1000, 1010);
        verify(subject.attack);
        subject.restart();
        compareCleared(subject);
        sample(1000, 5000);
        compare(subject.bassSmoothed, 1);
        verify(!subject.attack, "The first frame after restart establishes a new baseline");
    }

    function test_lifecycleReset_data() {
        return [
            {
                tag: "active",
                property: "active"
            },
            {
                tag: "visibility",
                property: "plasmoidVisible"
            }
        ];
    }

    function test_lifecycleReset(data) {
        subject[data.property] = true;
        sample(0, 1000);
        sample(1000, 1010);
        verify(subject.attack);
        subject[data.property] = false;
        compareCleared(subject);
        subject[data.property] = true;
        sample(1000, 5000);
        compare(subject.bassSmoothed, 1);
        verify(!subject.attack, "Resuming audio must establish a fresh baseline");
    }

    function test_backendFailureResetsAnalysis() {
        sample(0, 1000);
        sample(1000, 1010);
        verify(subject.attack);
        subject.handleStatus("error no-cava apt-get");
        verify(subject.backendFailed);
        compareCleared(subject);
        subject.handleStatus("ok pipewire");
        verify(!subject.backendFailed);
        sample(1000, 5000);
        compare(subject.bassSmoothed, 1);
        verify(!subject.attack, "Backend recovery must establish a fresh baseline");
    }

    function test_delayedLegacyFrameAfterResetIsIgnored() {
        deferredRead = null;
        const core = createTemporaryObject(coreComponent, this, {
            commandSourceComponent: deferredSourceComponent,
            runtimeDirectory: "/tmp/audio-band-analysis-absent-" + Date.now()
        });
        verify(core !== null);
        verify(core.handleData("900;900;900;900;", 1000));
        core.readBars();
        verify(deferredRead !== null);
        const stale = deferredRead;
        core.active = true;
        compareCleared(core);
        const previousBars = core.bars.slice();
        const previousTime = core.frameTimeMs;
        stale.emitter.newData(stale.source, {
            stdout: "1000;1000;1000;1000;"
        });
        compareCleared(core);
        compare(core.bars, previousBars, "A pre-reset callback must not change rendered bars");
        compare(core.frameTimeMs, previousTime, "A pre-reset callback must not advance rendering time");
        deferredRead = null;
        core.readBars();
        verify(deferredRead !== null, "Discarding a callback must release the reader for its next request");
        deferredRead.emitter.newData(deferredRead.source, {
            stdout: "500;500;500;500;"
        });
        compareBands(core, 0.5, 0.5, 0.5);
        compare(core.bassSmoothed, 0.5);
        verify(!core.attack, "The first fresh legacy frame establishes the new baseline");
    }
}
