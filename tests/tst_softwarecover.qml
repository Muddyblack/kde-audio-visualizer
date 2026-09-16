import QtQuick
import QtTest
import "../package/contents/ui" as Shared

TestCase {
    name: "SoftwareCover"
    visible: true
    when: windowShown
    width: 100
    height: 100
    Shared.SoftwareCover {
        id: cover
        width: 80
        height: 80
        radius: 40
        imageSize: Qt.size(4, 2)
    }
    readonly property var painter: findChild(cover, "softwareCoverCanvas")
    SignalSpy {
        id: paints
        target: painter
        signalName: 'painted'
    }
    function test_cropMaskDimAndClear() {
        cover.rasterScale = 3;
        compare(painter.canvasSize.width, 240);
        compare(painter.canvasSize.height, 240);
        cover.source = Qt.resolvedUrl('fixtures/cover-red-blue.ppm');
        tryVerify(() => painter.isImageLoaded(cover.source));
        tryVerify(() => paints.count > 0);
        wait(40);
        let picture = grabImage(cover);
        compare(painter.getContext("2d").getImageData(0, 0, 1, 1).data[3], 0);
        verify(picture.alpha(40, 40) > 240);
        verify(picture.red(20, 40) > picture.blue(20, 40));
        const count = paints.count;
        wait(100);
        compare(paints.count, count, 'Static covers must not repaint continuously');
        cover.grayed = true;
        tryVerify(() => paints.count > count);
        wait(40);
        picture = grabImage(cover);
        verify(picture.red(20, 40) > 100 && picture.red(20, 40) < 230);
        const previous = paints.count;
        cover.source = '';
        tryVerify(() => paints.count > previous);
        wait(40);
        compare(painter.getContext("2d").getImageData(40, 40, 1, 1).data[3], 0);
    }
}
