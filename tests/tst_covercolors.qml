import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    name: "CoverColors"
    when: windowShown
    visible: true
    width: 100
    height: 100
    CoverColors {
        id: sampler
        source: Qt.resolvedUrl("fixtures/cover-red-blue.ppm").toString()
    }
    SignalSpy {
        id: paints
        target: sampler
        signalName: "painted"
    }
    function test_staticCoverIsSampledOnceAndClears() {
        tryCompare(sampler, "ready", true);
        verify(sampler.primary.r > 0.9 && sampler.primary.b < 0.1);
        verify(sampler.secondary.b > 0.9 && sampler.secondary.r < 0.1);
        paints.clear();
        wait(100);
        compare(paints.count, 0, "A static cover does not keep painting");
        sampler.source = "";
        compare(sampler.ready, false);
        verify(Qt.colorEqual(sampler.primary, sampler.fallback));
    }
}
