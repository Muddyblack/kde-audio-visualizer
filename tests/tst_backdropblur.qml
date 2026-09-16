import QtQuick
import QtTest
import "../package/contents/ui" as Shared

TestCase {
    name: "BackdropBlur"
    when: windowShown
    visible: true
    width: 500
    height: 400
    Rectangle {
        id: wallpaper
        anchors.fill: parent
        color: "#cc5577"
        Row {
            Repeater {
                model: 50
                Rectangle {
                    required property int index
                    width: 10
                    height: wallpaper.height
                    color: index % 2 ? "white" : "black"
                }
            }
        }
    }
    Item {
        id: host
        x: 50
        y: 70
        width: 200
        height: 120
        Shared.BackdropBlur {
            id: blur
            x: 10
            y: 5
            width: 100
            height: 60
            sourceItem: wallpaper
        }
    }
    function test_gpuBlursWallpaper() {
        if (GraphicsInfo.api === GraphicsInfo.Software)
            skip("Wallpaper blur needs the GPU scene graph");
        verify(blur.available);
        verify(waitForRendering(blur));
        wait(150);
        const picture = grabImage(blur);
        const middle = picture.red(50, 30);
        verify(middle > 30 && middle < 225, "Sharp wallpaper stripes should blend into frosted glass");
    }

    function test_tracksWallpaperCrop() {
        failOnWarning(/Binding loop|TypeError|ReferenceError/);
        compare(blur.sampleRect, Qt.rect(60, 75, 100, 60));
        host.x = 90;
        compare(blur.sampleRect, Qt.rect(100, 75, 100, 60));
        host.transformOrigin = Item.TopLeft;
        host.scale = 2;
        compare(blur.sampleRect, Qt.rect(110, 80, 200, 120));
        if (GraphicsInfo.api === GraphicsInfo.Software)
            verify(!blur.available, "Software keeps the tint without creating a shader");
        blur.sourceItem = host;
        verify(!blur.safeSource, "Never capture an ancestor containing the effect");
        blur.sourceItem = null;
        verify(!blur.available);
        compare(blur.sampleRect, Qt.rect(0, 0, 0, 0));
    }
}
