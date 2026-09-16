import QtQuick
import QtTest
import "../package/contents/ui" as UI

TestCase {
    name: "FittedFrame"
    when: windowShown
    visible: true
    width: 800
    height: 800

    UI.FittedFrame {
        id: frame
        property int clicks: 0
        MouseArea {
            id: button
            x: 100
            y: 200
            width: 50
            height: 30
            onClicked: frame.clicks++
        }
    }

    function init() {
        frame.fitContents = true;
    }
    function test_readingLayoutReflows() {
        frame.designSize = Qt.size(380, 320);
        frame.width = 500;
        frame.height = 180;
        frame.fitContents = false;
        const canvas = findChild(frame, "fittedCanvas");
        compare(canvas.width, 500);
        compare(canvas.height, 180);
        compare(frame.fitScale, 1, "Reading text must not shrink with the host height");
    }
    function test_preservesProportions_data() {
        return [
            {
                tag: "wide-host",
                w: 700,
                h: 400
            },
            {
                tag: "tall-host",
                w: 300,
                h: 700
            },
            {
                tag: "small-host",
                w: 160,
                h: 180
            }
        ];
    }

    function test_preservesProportions(data) {
        frame.width = data.w;
        frame.height = data.h;
        frame.designSize = Qt.size(250, 332);
        wait(0);
        const canvas = findChild(frame, "fittedCanvas");
        const start = canvas.mapToItem(frame, 0, 0);
        const end = canvas.mapToItem(frame, canvas.width, canvas.height);
        verify(start.x >= -0.01 && start.y >= -0.01);
        verify(end.x <= frame.width + 0.01 && end.y <= frame.height + 0.01);
        fuzzyCompare((end.x - start.x) / (end.y - start.y), 250 / 332, 0.0001);
        const target = button.mapToItem(frame, 25, 15);
        const before = frame.clicks;
        mouseClick(frame, target.x, target.y);
        compare(frame.clicks, before + 1);
        // Switching back to a horizontal preset uses the same stored host size.
        frame.designSize = Qt.size(360, 104);
        compare(frame.width, data.w);
        compare(frame.height, data.h);
        fuzzyCompare(frame.fitScale, Math.min(data.w / 360, data.h / 104), 0.0001);
    }
}
