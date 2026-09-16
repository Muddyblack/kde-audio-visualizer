import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    name: "Waveform"
    when: windowShown
    visible: true
    width: 360
    height: 80

    Component {
        id: waveformComponent
        Waveform {
            width: 320
            height: 64
            numBars: 24
            bars: Array(24).fill(0)
            hasAudio: false
            visualizerType: 14
            visualFrameTime: 1000
            simpleRender: true
        }
    }
    Component {
        id: motionComponent
        WaveMotion {
            width: 320
            height: 64
            numBars: 24
            bars: Array(24).fill(800)
            style: 14
            frameTime: 1017
            active: false
            energy: 1
            lineWidth: 2
        }
    }
    property var subject

    function init() {
        subject = createTemporaryObject(waveformComponent, this);
        verify(subject !== null);
    }

    function test_firstAudioFrameAdvancesParticlesOnce() {
        const expected = createTemporaryObject(motionComponent, this);
        verify(expected !== null);
        // VisualizerCore publishes bars (and therefore hasAudio) before time.
        // Activation must wait for that same frame's final timestamp.
        subject.bars = Array(24).fill(800);
        subject.hasAudio = true;
        subject.visualFrameTime = 1017;
        expected.active = true;
        tryVerify(() => expected.particles.length > 0);
        compare(subject.particles, expected.particles, "Activation and timestamp publication must consume one audio frame");
    }

    function test_firstAttackCreatesOneRipple() {
        subject.visualizerType = 15;
        subject.attack = true;
        subject.bars = Array(24).fill(800);
        subject.hasAudio = true;
        subject.visualFrameTime = 1017;
        wait(30);
        compare(subject.ripples.length, 1, "The first onset must create exactly one ripple");
        fuzzyCompare(subject.ripples[0].age, .03, 1e-6);
    }

    function test_visibilityAndFailureResetMotion() {
        subject.bars = Array(24).fill(800);
        subject.hasAudio = true;
        subject.visualFrameTime = 1017;
        tryVerify(() => subject.particles.length > 0);
        subject.visible = false;
        compare(subject.particles, []);
        subject.visualFrameTime += 17;
        compare(subject.particles, []);
        subject.visible = true;
        subject.visualFrameTime += 17;
        tryVerify(() => subject.particles.length > 0);
        subject.backendFailed = true;
        compare(subject.particles, []);
        subject.visualFrameTime += 17;
        compare(subject.particles, []);
    }

    function test_rendererSelectionPreservesSharedState() {
        subject.bars = Array(24).fill(800);
        subject.hasAudio = true;
        subject.visualFrameTime = 1017;
        tryVerify(() => subject.particles.length > 0);
        const particles = subject.particles;
        const motion = findChild(subject, "waveMotion");
        verify(motion !== null);
        subject.simpleRender = false;
        wait(30);
        compare(findChild(subject, "waveMotion"), motion);
        verify(subject.particles === particles, "Changing the rendering backend must retain the shared motion state");
        subject.simpleRender = true;
        wait(30);
        verify(subject.particles === particles);
    }
}
