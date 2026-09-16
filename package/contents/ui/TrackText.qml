import QtQuick
import QtQuick.Controls as QQC

Text {
    id: root
    property bool secondary: false
    property bool trackUnknown: false
    property string displayTrack: ""
    property string rawTrack: ""
    property string artist: ""
    property string sourceHint: ""
    // The artist line is 0.82 of the title size, as in the HTML.
    property real titleSize: 11
    property real sizeFactor: 1
    // The "Nothing playing" message: regular weight at .55.
    property bool idle: false

    text: secondary ? (artist !== "" ? artist : sourceHint) : (trackUnknown ? qsTr("No track metadata") : displayTrack)
    opacity: idle && !secondary ? 0.55 : secondary ? 0.75 : (trackUnknown ? 0.75 : 1)
    font.bold: !secondary && !idle
    font.italic: secondary ? (artist === "" && sourceHint !== "") : trackUnknown
    font.pixelSize: Math.round((secondary ? titleSize * 0.82 : titleSize) * sizeFactor)
    // Curve glyphs stay sharp when the desktop host scales the card.
    renderType: Text.CurveRendering ?? Text.QtRendering
    textFormat: Text.PlainText
    elide: Text.ElideRight

    // Keep the original metadata available when the player publishes no title.
    HoverHandler {
        id: rawTrackHover
        enabled: !root.secondary
    }
    QQC.ToolTip.visible: !secondary && rawTrackHover.hovered && trackUnknown && rawTrack !== ""
    QQC.ToolTip.text: rawTrack.length > 160 ? rawTrack.substring(0, 160) + "…" : rawTrack
}
