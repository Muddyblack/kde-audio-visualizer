import QtCore
import QtQuick
import QtTest
import "../package/contents/ui"

// WaveShader must keep drawing what WaveCanvas draws. This renders both for
// every style and compares pixels over the dark background most desktops put
// behind the widget. It needs a GPU scene graph, so CI (software) skips it;
// on a desktop run: qmltestrunner -input tests/tst_rendererparity.qml
TestCase {
    id: testCase
    name: "RendererParity"
    when: windowShown
    visible: true
    width: 600
    height: 60

    readonly property var samples: [120, 380, 620, 540, 300, 820, 910, 700, 450, 260, 180, 520, 760, 640, 400, 350, 580, 830, 690, 420, 240, 160, 300, 90]

    Rectangle {
        anchors.fill: parent
        color: "#1e1e2e"
    }

    Component {
        id: canvasComponent
        WaveCanvas {
            y: 8
            width: 276
            height: 44
        }
    }
    Component {
        id: shaderComponent
        WaveShader {
            x: 300
            y: 8
            width: 276
            height: 44
        }
    }

    // `make parity` creates this directory; each row then saves its image pair.
    readonly property string imageDirectory: StandardPaths.writableLocation(StandardPaths.TempLocation).toString().replace(/^file:\/\//, "") + "/audio-visualizer-parity/"

    SignalSpy {
        id: paintSpy
        signalName: "painted"
    }

    function compareRenderers(tag, properties, limit) {
        const canvas = createTemporaryObject(canvasComponent, testCase, properties);
        const shader = createTemporaryObject(shaderComponent, testCase, properties);
        verify(canvas !== null && shader !== null);
        paintSpy.clear();
        paintSpy.target = canvas;
        // The canvas paints on a later frame and its glow layer one after that.
        tryVerify(() => paintSpy.count > 0, 5000, tag + ": WaveCanvas never painted");
        // One more frame lets the glow layer pick up the painted texture.
        wait(50);
        const canvasImage = grabImage(canvas);
        const shaderImage = grabImage(shader);
        canvasImage.save(imageDirectory + tag + "-canvas.png");
        shaderImage.save(imageDirectory + tag + "-shader.png");
        const difference = rootMeanSquare(canvasImage, shaderImage);
        console.log("parity", tag, difference.toFixed(4), "limit", limit);
        verify(difference < limit, tag + " differs from WaveCanvas by " + difference.toFixed(4) + " (limit " + limit + ")");
    }

    function rootMeanSquare(a, b) {
        let sum = 0;
        for (let y = 0; y < 44; y++) {
            for (let x = 0; x < 276; x++) {
                const p = a.pixel(x, y);
                const q = b.pixel(x, y);
                sum += (p.r - q.r) ** 2 + (p.g - q.g) ** 2 + (p.b - q.b) ** 2;
            }
        }
        return Math.sqrt(sum / (276 * 44 * 3));
    }

    // Limits sit just above the differences measured when the shader was fitted.
    function test_styles_data() {
        return [
            {
                tag: "wave-fill",
                style: 0,
                fill: true,
                limit: 0.02
            },
            {
                tag: "wave",
                style: 0,
                fill: false,
                limit: 0.02
            },
            {
                tag: "bars",
                style: 1,
                fill: true,
                limit: 0.025
            },
            {
                tag: "mirror-bars",
                style: 2,
                fill: true,
                limit: 0.035
            },
            {
                tag: "tech-line",
                style: 3,
                fill: true,
                limit: 0.025
            },
            {
                tag: "dots",
                style: 4,
                fill: true,
                limit: 0.015
            },
            {
                tag: "rings",
                style: 5,
                fill: true,
                limit: 0.015
            }
        ];
    }

    function test_styles(row) {
        if (GraphicsInfo.api === GraphicsInfo.Software)
            skip("WaveShader needs a GPU scene graph");
        compareRenderers(row.tag, {
            bars: samples,
            numBars: samples.length,
            hasAudio: true,
            waveColor: "#b4befe",
            lineWidth: 1.8,
            fillWave: row.fill,
            glowWave: true,
            visualizerType: row.style
        }, row.limit);
    }

    // Measured on an OpenGL desktop (2026-09-15); limits keep modest headroom.
    // The glow rows compare two approximations of the HTML blur (Canvas halos
    // and analytic shader bloom), so they carry the largest budgets. Do not
    // raise a limit merely to make a new difference pass.
    // compare_html_visualizers.py additionally checks the HTML drawing source
    // and can save actual Chromium/ShaderEffect image pairs and differences.
    function test_newStyles_data() {
        const measuredLimits = {
            "new-6-glow": 0.06,
            "new-10-glow": 0.025,
            "new-12": 0.025,
            "new-12-glow": 0.025,
            "new-15": 0.025,
            "new-15-glow": 0.055
        };
        const rows = [];
        const add = (tag, style, glow, palette, down) => rows.push({
                tag: tag,
                style: style,
                glow: glow,
                palette: palette,
                down: down,
                limit: measuredLimits[tag] ?? 0.02
            });
        for (let style = 6; style < 16; style++) {
            add("new-" + style, style, false, false, false);
            add("new-" + style + "-glow", style, true, false, false);
            add("new-" + style + "-palette", style, false, true, false);
        }
        for (const style of [6, 7, 8])
            add("new-" + style + "-down", style, false, true, true);
        return rows;
    }

    function test_newStyles(row) {
        if (GraphicsInfo.api === GraphicsInfo.Software)
            skip("New shader pixel comparison requires a GPU scene graph; this row is unverified");
        compareRenderers(row.tag, {
            bars: samples,
            numBars: samples.length,
            hasAudio: true,
            waveColor: "#b4befe",
            lineWidth: 1.8,
            fillWave: true,
            glowWave: row.glow,
            visualizerType: row.style,
            vizDirection: row.down ? "down" : "up",
            vizColorMode: row.palette ? "palette" : "solid",
            vizPalette: "aurora",
            hueReactive: row.palette,
            visualFrameTime: 2375,
            bass: 0.63,
            mid: 0.72,
            high: 0.48,
            energy: 1,
            bloom: row.palette ? 1.3 : 1,
            ribbonCurvature: 1,
            ribbonFullness: 1,
            peaks: samples.map(v => Math.min(1, v / 1000 + 0.1)),
            particles: [
                {
                    x: 48,
                    y: 10,
                    vy: -0.7,
                    r: 1.2,
                    life: 0.8
                },
                {
                    x: 137,
                    y: 25,
                    vy: -1.1,
                    r: 1.8,
                    life: 0.45
                },
                {
                    x: 222,
                    y: 16,
                    vy: -0.4,
                    r: 0.8,
                    life: 0.95
                }
            ],
            ripples: [
                {
                    x: 171,
                    age: 0.37
                }
            ]
        }, row.limit);
    }
}
