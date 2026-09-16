import QtQuick
import QtTest
import "../package/contents/ui"

// The software scene graph skips ShaderEffect, so these check what WaveShader
// feeds the GPU; tst_rendererparity.qml compares pixels on a desktop.
TestCase {
    id: testCase
    name: "WaveShader"
    when: windowShown
    visible: true
    width: 400
    height: 120

    Component {
        id: shaderComponent
        WaveShader {
            width: 320
            height: 44
            numBars: 6
        }
    }
    Component {
        id: canvasComponent
        WaveCanvas {
            width: 320
            height: 44
        }
    }
    Component {
        id: waveformComponent
        Waveform {
            width: 320
            height: 44
        }
    }
    Component {
        id: spyComponent
        SignalSpy {}
    }

    property var subject: null
    property var effect: null

    function init() {
        subject = createTemporaryObject(shaderComponent, testCase);
        verify(subject !== null);
        effect = findChild(subject, "waveEffect");
        verify(effect !== null);
    }

    function uploaded() {
        const blocks = [effect.levels0, effect.levels1];
        const values = [];
        for (const block of blocks)
            values.push(block.x, block.y, block.z, block.w);
        return values;
    }

    function test_uploadsCanvasLevels() {
        const bars = [100, 400, 800, 1000, 500, 250];
        subject.bars = bars;
        subject.hasAudio = true;
        const canvas = createTemporaryObject(canvasComponent, testCase, {
            numBars: bars.length
        });
        const values = uploaded();
        compare(effect.barCount, bars.length);
        for (let i = 0; i < bars.length; i++)
            fuzzyCompare(values[i], bars[i] / 1000 * canvas._tapers[i], 1e-6, "Bar " + i + " must match WaveCanvas");
        compare(values[6], 0, "Unused slots stay empty");
        compare(values[7], 0, "Unused slots stay empty");
    }

    function test_idleHiddenAndFailedFramesSkipUploads() {
        subject.hasAudio = true;
        subject.bars = [500, 500, 500, 500, 500, 500];
        fuzzyCompare(uploaded()[1], 0.5, 1e-6);

        subject.hasAudio = false;
        subject.bars = [900, 900, 900, 900, 900, 900];
        fuzzyCompare(uploaded()[1], 0.5, 1e-6, "Idle frames must not upload");
        subject.hasAudio = true;
        fuzzyCompare(uploaded()[1], 0.9, 1e-6, "Audio resuming uploads the latest frame");

        subject.visible = false;
        subject.bars = [200, 200, 200, 200, 200, 200];
        fuzzyCompare(uploaded()[1], 0.9, 1e-6, "Hidden frames must not upload");
        subject.visible = true;
        fuzzyCompare(uploaded()[1], 0.2, 1e-6, "Showing uploads the latest frame");

        subject.backendFailed = true;
        subject.bars = [700, 700, 700, 700, 700, 700];
        fuzzyCompare(uploaded()[1], 0.2, 1e-6, "A failed backend must not upload");
        subject.backendFailed = false;
        fuzzyCompare(uploaded()[1], 0.7, 1e-6);
    }

    function test_statesShowIdleLineOrEffect() {
        const idleLine = findChild(subject, "idleLine");
        verify(idleLine !== null);
        subject.hasAudio = false;
        verify(idleLine.visible && !effect.visible);
        subject.hasAudio = true;
        verify(!idleLine.visible && effect.visible);
        subject.backendFailed = true;
        verify(!idleLine.visible && !effect.visible, "The failure text needs an empty waveform");
    }

    function test_barCountIsCapped() {
        subject.numBars = 200;
        subject.bars = Array(200).fill(1000);
        subject.hasAudio = true;
        compare(effect.barCount, 128);
        fuzzyCompare(effect.levels15.x, 1, 1e-6, "Bar 60 is outside the edge taper");
        fuzzyCompare(effect.levels31.w, 0, 1e-6, "The last uploaded bar is the tapered edge");
    }

    function test_appearanceReachesUniforms() {
        subject.visualizerType = 4;
        subject.fillWave = false;
        subject.glowWave = false;
        subject.lineWidth = 3;
        subject.waveColor = "#eb408a";
        compare(effect.style, 4);
        compare(effect.fillAmount, 0);
        compare(effect.glowAmount, 0);
        compare(effect.lineWidth, 3);
        verify(Qt.colorEqual(effect.waveColor, "#eb408a"));
        compare(effect.canvasSize, Qt.size(320, 44));
    }

    function test_softwareSceneGraphUsesCanvas() {
        if (GraphicsInfo.api !== GraphicsInfo.Software)
            skip("Only the software scene graph falls back to WaveCanvas");
        const waveform = createTemporaryObject(waveformComponent, testCase, {
            bars: [300, 700, 900, 400],
            numBars: 4,
            hasAudio: true
        });
        verify(waveform !== null);
        verify(!waveform.shaderSupported);
        compare(findChild(waveform, "shaderLoader").item, null);
        const canvas = findChild(waveform, "canvasLoader").item;
        verify(canvas !== null);
        waveform.waveColor = "#42aed9";
        verify(Qt.colorEqual(canvas.waveColor, "#42aed9"), "Waveform forwards appearance to its renderer");
        compare(canvas.bars, waveform.bars);
    }

    function test_shaderFamilies_data() {
        const rows = [];
        for (let style = 0; style < 16; style++) {
            const family = style < 6 ? "visualizer" : style === 11 || style === 13 ? "viz_radial" : style === 14 ? "viz_particles" : style === 15 ? "viz_ribbon" : "viz_linear";
            rows.push({
                tag: "style-" + style,
                style: style,
                family: family
            });
        }
        return rows;
    }

    function test_shaderFamilies(row) {
        subject.visualizerType = row.style;
        verify(effect.fragmentShader.toString().endsWith("/" + row.family + ".frag.qsb"));
        compare(effect.style, row.style);
    }

    function test_newStylesLimitDensityAndRetainTaper() {
        subject.width = 64;
        subject.numBars = 128;
        subject.bars = Array(128).fill(500);
        subject.hasAudio = true;
        subject.visualizerType = 7;
        compare(effect.barCount, 16, "Dense meter fits four pixels per sample");
        compare(effect.levels0.x, 0);
        fuzzyCompare(effect.levels1.x, 0.5, 1e-6);
        compare(effect.levels3.w, 0);
        subject.visualizerType = 8;
        compare(effect.barCount, 25, "Mountain fits 2.5 pixels per sample");
        subject.visualizerType = 1;
        compare(effect.barCount, 128, "Legacy density stays unchanged");
    }

    function test_sharedMotionStateIsPackedAndBounded() {
        subject.hasAudio = true;
        subject.visualizerType = 6;
        subject.peaks = [0.2, 0.4, 0.9, 0.7, 0.5, 0.1];
        compare(effect.peaks0, Qt.vector4d(0.2, 0.4, 0.9, 0.7));
        compare(effect.peaks1, Qt.vector4d(0.5, 0.1, 0, 0));
        subject.visualizerType = 14;
        subject.particles = Array.from({
            length: 40
        }, (_, i) => ({
                    x: i * 3,
                    y: 12,
                    vy: -0.4,
                    r: 1.5,
                    life: 0.8
                }));
        compare(effect.particleCount, 32);
        compare(effect.particle31, Qt.vector4d(93, 12, 1.5, 0.8));
        subject.visualizerType = 15;
        subject.ripples = Array.from({
            length: 7
        }, (_, i) => ({
                    x: i * 10,
                    age: 0.25
                }));
        compare(effect.particleCount, 0);
        compare(effect.rippleCount, 4);
        compare(effect.ripple3, Qt.vector4d(30, 0.25, 0, 0));
        subject.reducedMotion = true;
        compare(effect.rippleCount, 0, "Reduced motion suppresses attack ripples");
        subject.visualizerType = 14;
        compare(effect.particleCount, 0, "Reduced motion suppresses particles");
        subject.reducedMotion = false;
        compare(effect.particleCount, 32);
    }

    function test_hiddenMotionStateUploadsOnResume() {
        subject.visualizerType = 14;
        subject.hasAudio = true;
        subject.particles = [
            {
                x: 15,
                y: 12,
                vy: -0.4,
                r: 1.5,
                life: 0.8
            }
        ];
        subject.visible = false;
        subject.particles = [
            {
                x: 29,
                y: 7,
                vy: -0.4,
                r: 2,
                life: 0.3
            }
        ];
        compare(effect.particle0, Qt.vector4d(15, 12, 1.5, 0.8));
        subject.visible = true;
        compare(effect.particle0, Qt.vector4d(29, 7, 2, 0.3));
        subject.backendFailed = true;
        subject.particles = [];
        compare(effect.particleCount, 1);
        subject.backendFailed = false;
        compare(effect.particleCount, 0);
    }

    function test_legacyFramesDoNotUpdateUnusedColorOrMotionUniforms() {
        const colorSpy = createTemporaryObject(spyComponent, testCase, {
            target: subject,
            signalName: "_colorsChanged"
        });
        verify(colorSpy.valid);
        subject.visualFrameTime = 2400;
        subject.bass = 0.8;
        subject.mid = 0.6;
        subject.high = 0.9;
        subject.energy = 0.4;
        compare(colorSpy.count, 0, "Solid legacy colors must not rebuild every audio frame");
        compare(effect.timeSeconds, 0);
        compare(effect.bass, 0);
        compare(effect.mid, 0);
        compare(effect.high, 0);
        compare(effect.energy, 1);

        subject.visualizerType = 15;
        fuzzyCompare(effect.timeSeconds, 2.4, 1e-6);
        compare(effect.bass, 0.8);
        compare(effect.mid, 0.6);
        compare(effect.high, 0.9);
        compare(effect.energy, 0.4);
        subject.reducedMotion = true;
        compare(effect.timeSeconds, 0);
        colorSpy.clear();
        subject.visualFrameTime = 3200;
        compare(effect.timeSeconds, 0);
        compare(colorSpy.count, 0);
    }

    function test_colorBloomAndDirectionUniforms() {
        subject.vizColorMode = "palette";
        subject.vizPalette = "ember";
        compare(effect.colorCount, 3);
        verify(Qt.colorEqual(effect.color0, "#ffc36b"));
        verify(Qt.colorEqual(effect.color1, "#ff6a3d"));
        verify(Qt.colorEqual(effect.color2, "#d6246e"));
        compare(effect.solidMode, 0);
        subject.vizDirection = "down";
        compare(effect.directionDown, 1);
        subject.bloom = 1.5;
        fuzzyCompare(effect.glowSigma, subject.glowSigma * 1.5, 1e-6);
        subject.bloom = 0;
        compare(effect.glowAmount, 0);

        subject.visualizerType = 13;
        subject.vizColorMode = "rainbow";
        compare(effect.colorCount, 6);
        compare(effect.opaqueOrb, 1, "The HTML HSL orb keeps its first two stops opaque");
        subject.vizColorMode = "solid";
        compare(effect.opaqueOrb, 0);
        subject.hueReactive = true;
        subject.high = 1;
        compare(effect.opaqueOrb, 1);
        subject.reducedMotion = true;
        compare(effect.opaqueOrb, 0);
    }
}
