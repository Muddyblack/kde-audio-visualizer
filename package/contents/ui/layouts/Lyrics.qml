import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../code/Layouts.js" as Layouts

// A reading surface: the whole synced lyric, with playback following the verse.
Item {
    id: root
    required property var view
    readonly property var cfg: view.configuration
    readonly property bool autoFollow: cfg.lyricsFollow ?? true
    readonly property string followPosition: cfg.lyricsFollowPosition ?? "center"
    readonly property real padding: Math.max(0, Math.min(48, cfg.lyricsPadding ?? 18, width / 4, height / 4))
    readonly property string fontFamily: cfg.lyricsFontFamily || view.defaultFontFamily
    readonly property int textSize: Math.max(12, Math.min(48, cfg.lyricsFontSize ?? 22))
    readonly property int alignment: (cfg.lyricsAlign ?? "left") === "center" ? Text.AlignHCenter : cfg.lyricsAlign === "right" ? Text.AlignRight : Text.AlignLeft
    property bool following: autoFollow
    property bool resetReadingPosition: false
    onAutoFollowChanged: {
        following = autoFollow;
        reposition.restart();
    }
    onFollowPositionChanged: reposition.restart()
    implicitWidth: Layouts.size(cfg)[0]
    implicitHeight: Layouts.size(cfg)[1]

    function followCurrent() {
        if (following && lines.count > 0)
            lines.positionViewAtIndex(Math.max(0, view.lyricIndex), followPosition === "top" ? ListView.Beginning : followPosition === "bottom" ? ListView.End : ListView.Center);
    }
    // Owned by the layout, so pending work is cancelled when a preview closes.
    Timer {
        id: reposition
        interval: 0
        onTriggered: {
            if (root.following)
                root.followCurrent();
            else if (root.resetReadingPosition && lines.count > 0)
                lines.positionViewAtIndex(0, ListView.Beginning);
            root.resetReadingPosition = false;
        }
    }

    Text {
        id: heading
        objectName: "lyricsHeading"
        visible: root.cfg.lyricsShowHeader ?? false
        x: root.padding
        y: root.padding
        width: Math.max(0, parent.width - root.padding * 2)
        text: [root.view.displayTrack || "", root.view.artist || ""].filter(Boolean).join(" · ")
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: root.fontFamily
        font.pixelSize: 13
        font.weight: Font.Medium
        horizontalAlignment: root.alignment
        color: root.view.textColor
        renderType: Text.CurveRendering ?? Text.QtRendering
        opacity: 0.75
    }

    ListView {
        id: lines
        objectName: "lyricsDocument"
        anchors.fill: parent
        anchors.margins: root.padding
        anchors.topMargin: root.padding + (heading.visible ? heading.implicitHeight + 12 : 0)
        clip: true
        model: root.view.lyricLines
        spacing: Math.max(0, Math.min(40, root.cfg.lyricsLineSpacing ?? 12))
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: root.view.lyricIndex
        // Space around the first/last verse lets either sit in the centre.
        header: Item {
            height: lines.height
            width: 1
        }
        footer: Item {
            height: lines.height
            width: 1
        }
        onMovementStarted: root.following = false
        onCurrentIndexChanged: reposition.restart()
        onCountChanged: {
            root.following = root.autoFollow;
            root.resetReadingPosition = !root.autoFollow;
            reposition.restart();
        }
        onWidthChanged: reposition.restart()
        onHeightChanged: reposition.restart()
        Controls.ScrollBar.vertical: Controls.ScrollBar {
            policy: (root.cfg.lyricsShowScrollbar ?? true) ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
        }
        delegate: Item {
            required property var modelData
            required property int index
            width: lines.width
            height: words.implicitHeight
            Text {
                id: words
                objectName: "lyricsVerse_" + parent.index
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(1, Math.min(parent.width - 16, root.cfg.lyricsMaxWidth ?? 600))
                text: parent.modelData.text || "♪"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                horizontalAlignment: root.alignment
                font.family: root.fontFamily
                font.pixelSize: root.textSize
                font.weight: parent.index === lines.currentIndex ? (root.cfg.lyricsCurrentWeight ?? Font.DemiBold) : (root.cfg.lyricsFontWeight ?? Font.Normal)
                font.italic: root.cfg.lyricsItalic ?? false
                font.letterSpacing: root.cfg.lyricsLetterSpacing ?? 0
                renderType: Text.CurveRendering ?? Text.QtRendering
                lineHeight: Math.max(1, Math.min(2, root.cfg.lyricsLineHeight ?? 1.25))
                color: parent.index !== lines.currentIndex ? root.view.textColor : root.cfg.lyricsHighlight === "custom" ? root.cfg.lyricsHighlightColor : root.cfg.lyricsHighlight === "accent" ? (root.view.waveColor ?? root.view.textColor) : root.view.textColor
                style: root.cfg.lyricsTextStyle === "outline" ? Text.Outline : root.cfg.lyricsTextStyle === "shadow" ? Text.Raised : Text.Normal
                styleColor: root.cfg.lyricsTextStyleColor ?? "#101318"
                opacity: parent.index === lines.currentIndex ? 1 : Math.max(0.1, Math.min(1, parent.index < lines.currentIndex ? (root.cfg.lyricsPastOpacity ?? 0.55) : (root.cfg.lyricsFutureOpacity ?? 0.55)))
                onImplicitHeightChanged: reposition.restart()
                Behavior on opacity {
                    NumberAnimation {
                        duration: root.cfg.reducedMotion ? 0 : 180
                    }
                }
            }
        }
    }

    Controls.Button {
        objectName: "lyricsFollowButton"
        visible: root.autoFollow && !root.following && lines.count > 0
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        text: qsTr("Follow current line")
        onClicked: {
            root.following = true;
            root.followCurrent();
        }
    }

    Text {
        objectName: "lyricsEmptyState"
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 40)
        visible: lines.count === 0
        text: {
            switch (root.view.lyricStatus) {
            case "idle":
                return qsTr("Play a song to see its lyrics");
            case "metadata":
                return qsTr("Waiting for the song title and artist…");
            case "loading":
                return qsTr("Finding lyrics…");
            case "error":
                return qsTr("Couldn't load lyrics");
            default:
                return qsTr("No synced lyrics available for this song");
            }
        }
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        font.family: root.fontFamily
        font.pixelSize: 15
        renderType: Text.CurveRendering ?? Text.QtRendering
        color: root.view.textColor
        opacity: 0.75
    }
}
