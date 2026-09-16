import QtQuick
import QtTest
import "../package/contents/ui" as Shared

TestCase {
    name: "OrbitRenderer"
    when: windowShown
    visible: true
    width: 420
    height: 220
    Shared.OrbitView {
        id: subject
        width: 190
        height: 190
        hasAudio: true
        bars: [100, 400, 900, 700, 300, 800, 500, 200]
        visualFrameTime: 2375
        glowWave: false
    }
    function test_fallbackAndState_data() {
        return ['bars', 'wave', 'dots', 'ribbon', 'sparks'].map(s => ({
                    tag: s,
                    style: s
                }));
    }
    function test_fallbackAndState(data) {
        failOnWarning(/TypeError|ReferenceError|Unable|Binding loop/);
        subject.simpleRender = true;
        subject.orbitStyle = data.style;
        subject.visualFrameTime += 33;
        compare(subject.shaderEnabled, false);
        compare(subject.rotation, 0, 'Ring phase must not rotate the QML item');
        compare(subject.values().length, subject.half);
        verify(subject.particles.length <= 32);
        waitForRendering(subject);
        const image = grabImage(subject);
        let lit = 0;
        for (let y = 0; y < 190; y += 3)
            for (let x = 0; x < 190; x += 3)
                if (image.red(x, y) > 10 || image.green(x, y) > 10 || image.blue(x, y) > 10)
                    lit++;
        verify(lit > 5, 'Canvas fallback must draw a ring');
        subject.backendFailed = true;
        compare(subject.drawing, false);
        subject.backendFailed = false;
    }
}
