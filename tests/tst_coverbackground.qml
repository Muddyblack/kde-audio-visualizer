import QtQuick
import QtTest
import "../package/contents/ui" as Shared

TestCase {
    id: test
    name: "CoverBackground"
    when: windowShown
    visible: true
    width: 500
    height: 420
    Shared.CardSurface {
        id: card
        hasPlayer: true
        artUrl: Qt.resolvedUrl("fixtures/cover-red-blue.ppm")
        configuration: ({
                showMpris: true,
                artBg: true,
                showBg: true,
                bgRadius: 0,
                artBgBlur: 0,
                artBgDim: 0,
                artBgTransparency: 1,
                surfaceStyle: "color",
                bgColor: "black"
            })
    }
    function test_fill_data() {
        return [
            {
                tag: "wide",
                w: 460,
                h: 90
            },
            {
                tag: "portrait",
                w: 180,
                h: 360
            },
            {
                tag: "square",
                w: 240,
                h: 240
            }
        ];
    }
    function test_fill(data) {
        failOnWarning(/ReferenceError|TypeError|Binding loop/);
        card.width = data.w;
        card.height = data.h;
        const source = findChild(card, "backgroundArtImage");
        const crop = findChild(card, "backgroundArtCrop");
        const effect = findChild(card, "backgroundArtEffect");
        tryCompare(source, "status", Image.Ready);
        compare(effect.source, crop);
        verify(crop.clip);
        compare(crop.width, data.w);
        compare(crop.height, data.h);
        compare(source.fillMode, Image.PreserveAspectCrop);
        wait(500);
        const picture = grabImage(card);
        for (const point of [[2, 2], [data.w - 3, 2], [2, data.h - 3], [data.w - 3, data.h - 3], [data.w / 2, data.h / 2]]) {
            const [x, y] = point;
            verify(picture.alpha(x, y) > 240, "Cover must fill every edge");
            verify(picture.red(x, y) > 100 || picture.blue(x, y) > 100, "Every edge must contain cover pixels");
        }
    }
}
