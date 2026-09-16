import QtQuick
import "StudioCatalog.js" as Catalog

// One static image, shared with the browser demo; no repaint loop.
Rectangle {
    id: backdrop
    property string kind: "dusk"
    // Raise for captures grabbed above 1:1; previews stay at 1.
    property real detail: 1
    readonly property var wallpaper: Catalog.StudioCatalog.wallpapers.find(item => item.id === kind) || Catalog.StudioCatalog.wallpapers[0]
    color: wallpaper.color
    clip: true
    Image {
        objectName: "wallpaperImage"
        anchors.fill: parent
        source: Qt.resolvedUrl("wallpapers/" + backdrop.wallpaper.file)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
        // Keep thumbnail decoding small and bound large previews.
        sourceSize.width: Math.min(1600 * backdrop.detail, Math.max(1, Math.ceil(Math.max(width, height * 1.8))))
    }
}
