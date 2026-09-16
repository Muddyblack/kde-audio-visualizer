import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    name: "WaveCanvas"
    when: windowShown
    visible: true
    width: 900
    height: 100

    Component {
        id: waveComponent
        WaveCanvas {
            width: 320
            height: 44
            numBars: 32
            waveColor: "#42aed9"
        }
    }
    Component {
        id: paintSpyComponent
        SignalSpy {
            signalName: "painted"
        }
    }
    property var subject: null
    SignalSpy {
        id: paints
        target: subject
        signalName: "painted"
    }

    function samples(value) {
        const result = [];
        for (let i = 0; i < 32; i++)
            result.push(value + (i * 11) % 100);
        return result;
    }

    function rendered() {
        tryVerify(() => paints.count > 0);
        return grabImage(subject);
    }

    function init() {
        subject = createTemporaryObject(waveComponent, this);
        verify(subject !== null);
        rendered();
        // Creation and the first texture upload may schedule a second paint.
        wait(40);
        paints.clear();
    }

    function test_idleFramesDoNotRepaint() {
        for (let i = 0; i < 20; i++)
            subject.bars = samples(i);
        wait(80);
        compare(paints.count, 0, "Idle sample updates must not redraw the idle line");
        subject.hasAudio = true;
        rendered();
        paints.clear();
        subject.hasAudio = false;
        rendered();
    }

    function test_hiddenFramesDoNotRepaintAndResume() {
        subject.hasAudio = true;
        subject.bars = samples(100);
        const before = rendered();
        subject.visible = false;
        wait(30);
        paints.clear();
        for (let i = 0; i < 20; i++)
            subject.bars = samples(700 + i);
        wait(80);
        compare(paints.count, 0, "Hidden audio must not spend time painting");
        subject.visible = true;
        const after = rendered();
        verify(!before.equals(after), "Showing the canvas must render the latest frame");
    }

    function test_backendFailureClearsAndRecovers() {
        subject.hasAudio = true;
        subject.bars = samples(600);
        const before = rendered();
        paints.clear();
        subject.backendFailed = true;
        const failure = rendered();
        verify(!before.equals(failure));
        compare(failure.pixel(160, 22), failure.pixel(10, 1), "Failure text needs an empty canvas behind it");
        paints.clear();
        subject.bars = samples(200);
        wait(80);
        compare(paints.count, 0, "Failed backends must not redraw for sample updates");
        subject.backendFailed = false;
        const after = rendered();
        verify(!failure.equals(after));
    }

    function test_idleThemeChangeRepaints() {
        subject.textColor = "#ff0000";
        const before = rendered();
        paints.clear();
        subject.textColor = "#0000ff";
        const after = rendered();
        verify(!before.equals(after), "A settled idle line must follow text color changes");
    }

    function test_appearanceChanges_data() {
        const rows = [];
        for (let style = 0; style < 16; style++)
            rows.push({
                tag: "style-" + style,
                style: style
            });
        return rows;
    }

    function test_appearanceChanges(row) {
        subject.visualizerType = row.style;
        subject.hasAudio = true;
        subject.bars = samples(800);
        const before = rendered();
        paints.clear();
        subject.waveColor = "#eb408a";
        subject.width = 421;
        subject.height = 37;
        subject.lineWidth = 7;
        const changed = rendered();
        verify(!before.equals(changed));
        // A fresh canvas is the oracle for invalidated palette/geometry caches.
        const fresh = createTemporaryObject(waveComponent, this, {
            x: 450,
            visualizerType: row.style,
            hasAudio: true,
            bars: subject.bars,
            waveColor: subject.waveColor,
            width: subject.width,
            height: subject.height,
            lineWidth: subject.lineWidth
        });
        verify(fresh !== null);
        const freshPaints = createTemporaryObject(paintSpyComponent, this, {
            target: fresh
        });
        verify(freshPaints !== null);
        fresh.requestPaint();
        tryVerify(() => freshPaints.count > 0);
        const expected = grabImage(fresh);
        verify(changed.equals(expected), "Appearance changes must discard stale cached paint state");
    }

    function test_legacyIgnoresUnusedMotionInputs() {
        subject.hasAudio = true;
        rendered();
        wait(50);
        paints.clear();
        // The shared audio frame updates these inputs for every renderer. A
        // Classic solid waveform must keep its cached paint and gradients.
        subject.visualFrameTime = 3000;
        subject.bass = .7;
        subject.mid = .8;
        subject.high = .9;
        subject.energy = .5;
        wait(80);
        compare(paints.count, 0, "Unused analysis and time must not repaint Classic");
    }

    function test_reducedMotionIgnoresTime_data() {
        return test_appearanceChanges_data();
    }

    function test_reducedMotionIgnoresTime(row) {
        subject.hasAudio = true;
        subject.visualizerType = row.style;
        subject.reducedMotion = true;
        // Exercise both decorative geometry and time-dependent colour modes.
        subject.vizColorMode = "rainbow";
        subject.hueReactive = true;
        rendered();
        wait(50);
        paints.clear();
        for (let i = 1; i < 20; i++)
            subject.visualFrameTime = i * 50;
        wait(80);
        compare(paints.count, 0, "Reduced motion must freeze decorative time without repainting");
    }
}
