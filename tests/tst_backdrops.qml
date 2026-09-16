import QtQuick
import QtTest
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/StudioCatalog.js" as Catalog

TestCase {
    name: "StudioWallpapers"
    when: windowShown
    width: 320
    height: 200
    visible: true
    Studio.Backdrop {
        id: backdrop
        anchors.fill: parent
    }
    function test_wallpapersLoad_data() {
        return Catalog.StudioCatalog.wallpapers.map(w => ({
                    tag: w.id,
                    wallpaper: w
                }));
    }
    function test_wallpapersLoad(data) {
        failOnWarning(/Error|Unable|Cannot/);
        backdrop.kind = data.wallpaper.id;
        const image = findChild(backdrop, "wallpaperImage");
        tryCompare(image, "status", Image.Ready);
        verify(image.source.toString().endsWith(data.wallpaper.file));
        compare(image.fillMode, Image.PreserveAspectCrop);
        verify(image.sourceSize.width <= 1600);
    }
    function test_unknownIdFallsBack() {
        backdrop.kind = "obsolete-wallpaper";
        const image = findChild(backdrop, "wallpaperImage");
        tryCompare(image, "status", Image.Ready);
        verify(image.source.toString().endsWith(Catalog.StudioCatalog.wallpapers[0].file));
    }
}
