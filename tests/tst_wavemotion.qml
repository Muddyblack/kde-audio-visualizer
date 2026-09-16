import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/code/WaveMath.js" as WaveMath

TestCase {
    name: "WaveMotion"
    when: windowShown
    Component {
        id: motionComponent
        WaveMotion {
            width: 320
            height: 64
            numBars: 24
            bars: Array(24).fill(800)
            active: true
        }
    }
    property var subject
    function init() {
        subject = createTemporaryObject(motionComponent, this);
        verify(subject !== null);
    }
    function test_peakHoldAndDecayUseOnlyNewAudioFrames() {
        subject.style = 6;
        subject.frameTime = 1000;
        fuzzyCompare(subject.peaks[12], 0.8, 1e-6);
        subject.bars = Array(24).fill(100);
        compare(subject.peaks[12], 0.8);
        subject.advance();
        compare(subject.peaks[12], 0.8, "Painting or reading again cannot advance state");
        subject.frameTime += 1000 / 60;
        fuzzyCompare(subject.peaks[12], 0.79, 1e-6);
        subject.active = false;
        compare(subject.peaks, []);
        subject.frameTime += 100;
        compare(subject.peaks, []);
    }
    function test_particlesStayBoundedAndDeterministic() {
        subject.style = 14;
        const other = createTemporaryObject(motionComponent, this, {
            style: 14
        });
        for (let i = 1; i <= 240; i++) {
            subject.frameTime = i * 1000 / 60;
            other.frameTime = subject.frameTime;
            verify(subject.particles.length <= 32);
            compare(subject.particles, other.particles);
        }
        verify(subject.particles.length > 0);
        subject.reducedMotion = true;
        compare(subject.particles, []);
        for (let i = 1; i < 10; i++)
            subject.frameTime += 17;
        compare(subject.particles, []);
    }
    function test_ripplesRequireAttackAndStayBounded() {
        subject.style = 15;
        subject.frameTime = 1000;
        compare(subject.ripples, []);
        subject.attack = true;
        for (let i = 0; i < 20; i++)
            subject.frameTime += 17;
        verify(subject.ripples.length > 0 && subject.ripples.length <= 4);
        subject.attack = false;
        for (let i = 0; i < 120; i++)
            subject.frameTime += 17;
        compare(subject.ripples, []);
        subject.style = 0;
        compare(subject.particles, []);
        compare(subject.peaks, []);
    }
    function test_paletteColoursAndDefaults() {
        const accent = Qt.rgba(0.4, 0.6, 0.8, 0.7);
        const solid = WaveMath.colorStops(accent, "solid", "aurora", "red", "blue", false, 0.5, 20, false);
        verify(Qt.colorEqual(solid[0], accent));
        const aurora = WaveMath.colorStops(accent, "palette", "aurora", "red", "blue", false, 0.5, 0, false);
        compare(aurora.length, 3);
        verify(Qt.colorEqual(aurora[0], "#5ef2c1"));
        verify(Qt.colorEqual(aurora[1], "#4aa8ff"));
        verify(Qt.colorEqual(aurora[2], "#b57bff"));
        const cover = WaveMath.colorStops(accent, "cover", "aurora", "red", "blue", false, 0.5, 0, false);
        verify(Qt.colorEqual(cover[0], "red") && Qt.colorEqual(cover[1], accent) && Qt.colorEqual(cover[2], "blue"));
        const shifted = WaveMath.shiftHue("red", 120);
        // QColor retains its HSL/RGB storage spec; compare the rendered channels.
        compare(shifted.r, 0);
        compare(shifted.g, 1);
        compare(shifted.b, 0);
        compare(shifted.a, 1);
    }
    function test_reducedMotionFreezesRainbowAndHueDrift() {
        for (const mode of ["solid", "gradient", "palette", "rainbow"]) {
            const first = WaveMath.colorStops("#b4befe", mode, "iris", "red", "blue", true, 0, 0, true);
            const last = WaveMath.colorStops("#b4befe", mode, "iris", "red", "blue", true, 1, 500, true);
            compare(first, last);
        }
        const rainbow = WaveMath.colorStops("red", "rainbow", "iris", "red", "blue", false, 0.5, 0, false);
        const moved = WaveMath.colorStops("red", "rainbow", "iris", "red", "blue", false, 0.5, 1, false);
        compare(rainbow.length, 6);
        verify(!Qt.colorEqual(rainbow[0], moved[0]));
    }
}
