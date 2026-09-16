import QtQuick

// A desktop host can retain an old rectangle after a layout change. Keep the
// complete card at its design proportions, including text and input targets.
Item {
    id: frame
    // Reading layouts reflow at the host size instead of shrinking the text.
    property bool fitContents: true
    property size designSize: Qt.size(360, 104)
    default property alias content: canvas.data
    readonly property real fitScale: !fitContents ? 1 : designSize.width > 0 && designSize.height > 0 ? Math.max(0, Math.min(width / designSize.width, height / designSize.height)) : 0
    implicitWidth: designSize.width
    implicitHeight: designSize.height

    Item {
        id: canvas
        objectName: "fittedCanvas"
        width: frame.fitContents ? frame.designSize.width : frame.width
        height: frame.fitContents ? frame.designSize.height : frame.height
        anchors.centerIn: parent
        scale: frame.fitScale
        enabled: frame.fitScale > 0
    }
}
