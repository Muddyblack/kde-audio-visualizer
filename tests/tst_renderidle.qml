import QtQuick
import QtTest
import "../package/contents/ui" as Shared

TestCase {
    name: "RenderIdle"
    visible: true
    when: windowShown
    width: 240
    height: 240

    Component {
        id: orbitComponent
        Shared.OrbitCanvas {
            width: 190
            height: 190
            shaderEnabled: true
            hasAudio: true
            bars: [100, 500, 900]
        }
    }
    Component {
        id: shaderComponent
        Shared.OrbitShader {
            anchors.fill: parent
        }
    }
    Component {
        id: ambientComponent
        Shared.WaveArea {
            width: 190
            height: 100
            ambient: true
            configuration: ({
                    framerate: 20,
                    lineWidth: 2,
                    fillWave: false,
                    glowWave: false,
                    visualizerType: 0
                })
            visualizer: ({
                    numBars: 24,
                    maxRange: 1000
                })
        }
    }

    function test_orbitUniformsStopAndResume() {
        const orbit = createTemporaryObject(orbitComponent, this);
        const shader = createTemporaryObject(shaderComponent, orbit, {
            orbit: orbit
        });
        verify(shader.levels0.x > 0);
        const initial = shader.levels0;
        orbit.visible = false;
        orbit.bars = [900, 800, 700];
        orbit.particles = [
            {
                a: 0,
                r: 12,
                s: 2,
                life: 1
            }
        ];
        compare(shader.levels0, initial, "Hidden audio must not upload");
        compare(shader.particle0.x, 0, "Hidden particles must not upload");
        orbit.visible = true;
        compare(shader.levels0.x, 0.9);
        compare(shader.particle0.x, 12);
        orbit.hasAudio = false;
        compare(shader.levels0, Qt.vector4d(0, 0, 0, 0));
        orbit.bars = [1000, 1000, 1000];
        compare(shader.levels0, Qt.vector4d(0, 0, 0, 0));
        orbit.hasAudio = true;
        compare(shader.levels0.x, 1);
    }

    function test_ambientClockStops_data() {
        return [
            {
                tag: "hidden",
                key: "visible",
                value: false
            },
            {
                tag: "reduced motion",
                key: "reducedMotion",
                value: true
            },
            {
                tag: "battery saver",
                key: "batterySaving",
                value: true
            }
        ];
    }
    function test_ambientClockStops(data) {
        const wave = createTemporaryObject(ambientComponent, this);
        tryVerify(() => wave._ambientTime > 0);
        wave[data.key] = data.value;
        const stopped = wave._ambientTime;
        wait(160);
        compare(wave._ambientTime, stopped);
        wave[data.key] = !data.value;
        tryVerify(() => wave._ambientTime > stopped);
    }
}
