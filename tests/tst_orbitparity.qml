import QtQuick
import QtTest
import "../package/contents/ui" as Shared

// Measures new orbit shader differences. A desktop reviewer must accept the
// captured images; a successful capture alone is not visual/power acceptance.
TestCase {
    name: "OrbitParity"
    when: windowShown
    visible: true
    width: 420
    height: 210
    Shared.OrbitCanvas {
        id: canvas
        width: 190
        height: 190
        hasAudio: true
        bars: [120, 380, 620, 540, 300, 820, 910, 700, 450, 260, 180, 520, 760, 640, 400, 350, 580, 830, 690, 420, 240, 160, 300, 90]
        visualFrameTime: 2375
        vizColorMode: 'palette'
        fillWave: true
    }
    Shared.OrbitShader {
        id: shader
        x: 210
        width: 190
        height: 190
        orbit: canvas
    }
    function test_epochPhasesStayPrecise() {
        canvas.visualFrameTime = 1789560000000;
        const rotation = shader.ringRotation;
        const time = shader.timeSeconds;
        verify(rotation >= 0 && rotation < Math.PI * 2);
        verify(time >= 0 && time < Math.PI * 10);
        canvas.visualFrameTime += 67;
        fuzzyCompare(shader.ringRotation - rotation, 0.067 * 0.2, 0.000001);
        fuzzyCompare(shader.timeSeconds - time, 0.067, 0.000001);
        canvas.visualFrameTime = 2375;
    }

    function test_capture_data() {
        const rows = [];
        for (const style of ['bars', 'wave', 'dots', 'ribbon', 'sparks'])
            for (const glow of [false, true])
                for (const timestamp of [2375, 1789560000000])
                    rows.push({
                        tag: style + (glow ? '-glow' : '') + (timestamp > 2375 ? '-epoch' : ''),
                        timestamp: timestamp,
                        style: style,
                        glow: glow
                    });
        return rows;
    }
    function test_capture(data) {
        if (GraphicsInfo.api === GraphicsInfo.Software)
            skip('OrbitShader needs a GPU scene graph');
        canvas.visualFrameTime = data.timestamp;
        canvas.orbitStyle = data.style;
        canvas.glowWave = data.glow;
        canvas.particles = [
            {
                a: 0.3,
                r: 60,
                v: 1,
                life: .8,
                s: 1.5
            },
            {
                a: 2,
                r: 70,
                v: 1,
                life: .6,
                s: 1.8
            }
        ];
        waitForRendering(shader);
        tryCompare(shader, 'status', ShaderEffect.Compiled);
        wait(150);
        const reference = grabImage(canvas), actual = grabImage(shader);
        let sum = 0, lit = 0;
        for (let y = 0; y < 190; y++)
            for (let x = 0; x < 190; x++) {
                for (const channel of ['red', 'green', 'blue']) {
                    const d = reference[channel](x, y) - actual[channel](x, y);
                    sum += d * d;
                }
                if (actual.alpha(x, y) > 0)
                    lit++;
            }
        verify(lit > 20, 'Shader must draw visible pixels');
        reference.save('/tmp/orbit-' + data.tag + '-canvas.png');
        actual.save('/tmp/orbit-' + data.tag + '-shader.png');
        console.log('orbit parity', data.tag, 'RMSE', Math.sqrt(sum / (190 * 190 * 3)) / 255);
    }
}
