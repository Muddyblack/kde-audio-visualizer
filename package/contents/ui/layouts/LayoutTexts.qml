import QtQuick
import QtQuick.Layouts
import ".."

// Player chip, title, artist, album and lyric line at the configured size and
// alignment. Layouts scale them like the HTML (for example Stacked uses title
// ×1.6 and artist ×1.05).
ColumnLayout {
    id: root
    objectName: "layoutTexts"
    required property var view
    property real titleFactor: 1
    property real artistSize: 0.82
    property real albumSize: 0.72
    property real lyricSize: 1
    property int sourceSize: 7
    // Orbit always centres its texts.
    property int alignmentOverride: -1
    readonly property var cfg: view.configuration
    readonly property int alignment: alignmentOverride >= 0 ? alignmentOverride : cfg.textAlign === "center" ? Text.AlignHCenter : cfg.textAlign === "right" ? Text.AlignRight : Text.AlignLeft
    readonly property int layoutAlignment: alignment === Text.AlignHCenter ? Qt.AlignHCenter : alignment === Text.AlignRight ? Qt.AlignRight : Qt.AlignLeft
    readonly property real ts: cfg.titleSize ?? 11
    // Titles over 26 characters scroll (14 s loop, 12 % pause) on the audio clock.
    readonly property bool marquee: (cfg.marquee ?? false) && !(cfg.reducedMotion ?? false) && view.displayTrack.length > 26
    readonly property real marqueeOffset: {
        if (!marquee)
            return 0;
        const phase = (view.visualFrameTime % 14000) / 14000;
        return phase < 0.12 ? 0 : (phase - 0.12) / 0.88 * (title.implicitWidth + 40);
    }
    spacing: 0

    RowLayout {
        objectName: "sourceRow"
        visible: ((root.cfg.showSource ?? false) || (root.cfg.showPlayerSwitch ?? false)) && root.view.hasPlayer
        Layout.alignment: root.layoutAlignment
        Layout.bottomMargin: 3
        Layout.maximumWidth: root.width
        spacing: 5
        opacity: 0.65

        Rectangle {
            implicitWidth: 5
            implicitHeight: 5
            radius: 2.5
            color: root.view.waveColor
        }
        Text {
            objectName: "sourceChip"
            renderType: Text.CurveRendering ?? Text.QtRendering
            font.family: root.view.defaultFontFamily
            Layout.fillWidth: true
            text: root.view.playerName.toUpperCase()
            color: root.view.textColor
            font.pixelSize: root.sourceSize
            font.letterSpacing: 1.3
            elide: Text.ElideRight
        }
        Rectangle {
            visible: root.cfg.showPlayerSwitch ?? false
            implicitWidth: switchLabel.implicitWidth + 10
            implicitHeight: switchLabel.implicitHeight
            radius: 6
            color: Qt.rgba(1, 1, 1, 0x1a / 255)
            Text {
                id: switchLabel
                objectName: "playerSwitchLabel"
                anchors.centerIn: parent
                text: root.view.playerCount + " ▾"
                color: root.view.textColor
                font.pixelSize: root.sourceSize
                font.letterSpacing: 0.5
            }
            MouseArea {
                objectName: "playerSwitchArea"
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof root.view.switchPlayer === "function")
                        root.view.switchPlayer();
                }
            }
        }
    }

    Item {
        id: titleViewport
        Layout.fillWidth: true
        implicitHeight: title.implicitHeight
        layer.enabled: root.marquee && GraphicsInfo.api !== GraphicsInfo.Software
        layer.smooth: true
        layer.effect: ShaderEffect {
            property var source
            property real fadeFraction: Math.min(0.2, 8 / Math.max(1, titleViewport.width))
            fragmentShader: Qt.resolvedUrl("../../shaders/text_fade.frag.qsb")
        }
        clip: root.marquee

        TrackText {
            id: title
            x: root.marquee ? -root.marqueeOffset : 0
            width: root.marquee ? implicitWidth : parent.width
            elide: root.marquee ? Text.ElideNone : Text.ElideRight
            font.family: root.view.defaultFontFamily
            titleSize: root.ts
            sizeFactor: root.titleFactor
            horizontalAlignment: root.marquee ? Text.AlignLeft : root.alignment
            idle: root.view.idleMessage
            displayTrack: root.view.idleMessage ? qsTr("Nothing playing") : root.view.displayTrack
            trackUnknown: root.view.trackUnknown
            rawTrack: root.view.track
            color: root.view.textColor
        }
        TrackText {
            visible: root.marquee
            x: title.x + title.implicitWidth + 40
            font.family: root.view.defaultFontFamily
            titleSize: root.ts
            sizeFactor: root.titleFactor
            displayTrack: root.view.displayTrack
            trackUnknown: root.view.trackUnknown
            rawTrack: root.view.track
            color: root.view.textColor
        }
    }

    TrackText {
        Layout.fillWidth: true
        secondary: true
        font.family: root.view.defaultFontFamily
        titleSize: root.ts
        sizeFactor: root.artistSize / 0.82
        horizontalAlignment: root.alignment
        artist: root.view.idleMessage ? qsTr("Start music in any player") : root.view.artist
        sourceHint: root.view.sourceHint
        color: root.view.textColor
    }

    Text {
        objectName: "albumLine"
        renderType: Text.CurveRendering ?? Text.QtRendering
        font.family: root.view.defaultFontFamily
        Layout.fillWidth: true
        Layout.topMargin: 1
        visible: (root.cfg.showAlbum ?? false) && root.view.album !== ""
        text: root.view.album + (root.view.year !== "" ? " · " + root.view.year : "")
        horizontalAlignment: root.alignment
        color: root.view.textColor
        opacity: 0.4
        font.pixelSize: Math.max(1, Math.round(root.ts * root.albumSize))
        elide: Text.ElideRight
    }

    Text {
        objectName: "lyricLine"
        Layout.fillWidth: true
        Layout.topMargin: 1
        visible: (root.cfg.showLyrics ?? false) && root.view.lyricLine !== ""
        text: root.view.lyricLine
        horizontalAlignment: root.cfg.lyricsAlign === "center" ? Text.AlignHCenter : root.cfg.lyricsAlign === "right" ? Text.AlignRight : Text.AlignLeft
        color: root.cfg.lyricsHighlight === "custom" ? root.cfg.lyricsHighlightColor : root.cfg.lyricsHighlight === "accent" ? root.view.waveColor : root.view.textColor
        font.weight: root.cfg.lyricsCurrentWeight ?? Font.Medium
        font.italic: root.cfg.lyricsItalic ?? false
        font.letterSpacing: root.cfg.lyricsLetterSpacing ?? 0
        style: root.cfg.lyricsTextStyle === "outline" ? Text.Outline : root.cfg.lyricsTextStyle === "shadow" ? Text.Raised : Text.Normal
        styleColor: root.cfg.lyricsTextStyleColor ?? "#101318"
        font.family: root.cfg.lyricsFontFamily || root.view.defaultFontFamily
        renderType: Text.CurveRendering ?? Text.QtRendering
        textFormat: Text.PlainText
        font.pixelSize: Math.max(10, Math.min(24, root.cfg.lyricsInlineFontSize ?? Math.round(root.ts * root.lyricSize)))
        elide: Text.ElideRight
    }
}
