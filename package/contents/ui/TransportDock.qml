import QtQuick 2.15
import QtQuick.Layouts 1.1
import QtQuick.Effects

// Playback controls. Styles follow the HTML `.dock`: glass (the original
// pill), bare, accent (round accent play button) and hover (glass, shown while
// the card is hovered). Shuffle/repeat use the MPRIS player properties.
Item {
    id: root

    required property var configuration
    property var player: null
    property bool isPlaying: false
    property color controlColor: "#ffffff"
    property color accentColor: "#ffffff"
    property bool cardHovered: false

    readonly property string dockStyle: configuration.dockStyle ?? "glass"
    readonly property bool framed: dockStyle === "glass" || dockStyle === "hover"
    readonly property bool showSkip: configuration.showSkipButtons ?? true
    readonly property bool showExtras: configuration.showShuffleRepeat ?? false
    // Plasma reports ShuffleStatus (Off = 1, On = 2) and LoopStatus (None = 1,
    // Playlist = 2, Track = 3); Quickshell a bool and MprisLoopState (None = 0).
    readonly property bool shuffleOn: !!player && (typeof player.shuffle === "boolean" ? player.shuffle : player.shuffle === 2)
    readonly property bool canShuffle: !!player && player.canControl !== false && player.shuffleSupported !== false && (typeof player.shuffle === "boolean" || player.shuffle === 1 || player.shuffle === 2)
    readonly property bool canLoop: !!player && player.canControl !== false && player.loopSupported !== false && (player.loopStatus !== undefined ? player.loopStatus >= 1 : player.loopState !== undefined)
    readonly property bool loopTrack: !!player && (player.loopStatus !== undefined ? player.loopStatus === 3 : player.loopState === 1)
    readonly property bool loopOn: !!player && (player.loopStatus !== undefined ? player.loopStatus >= 2 : (player.loopState ?? 0) > 0)
    readonly property bool hiddenUntilHover: dockStyle === "hover" && !cardHovered

    implicitWidth: framed ? Math.max(88, controlRow.implicitWidth + 12) : controlRow.implicitWidth
    implicitHeight: 26
    opacity: hiddenUntilHover ? 0 : 1
    Behavior on opacity {
        NumberAnimation {
            duration: 250
        }
    }
    transform: Translate {
        y: root.hiddenUntilHover ? 3 : 0
        Behavior on y {
            NumberAnimation {
                duration: 250
            }
        }
    }

    function toggleShuffle() {
        const p = player;
        if (!canShuffle)
            return;
        if (typeof p.shuffle === "boolean")
            p.shuffle = !p.shuffle;
        else
            p.shuffle = p.shuffle === 2 ? 1 : 2;
    }
    // None → Playlist → Track → None.
    function cycleLoop() {
        const p = player;
        if (!canLoop)
            return;
        if (p.loopStatus !== undefined)
            p.loopStatus = p.loopStatus === 2 ? 3 : p.loopStatus === 3 ? 1 : 2;
        else if (p.loopState !== undefined)
            p.loopState = p.loopState === 0 ? 2 : p.loopState === 2 ? 1 : 0;
    }

    Rectangle {
        anchors.fill: parent
        visible: root.framed
        radius: height / 2
        // Darker, cleaner glass: a deeper translucent base reads as
        // a single calm surface against busy album art, instead of
        // the milky look a light tint gives over a bright cover.
        color: root.configuration.useSystemDockBg ? Qt.rgba(0, 0, 0, 0.28) : root.configuration.customDockBgColor
        border.color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1

        layer.enabled: visible
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.35)
            shadowOpacity: 0.35
            shadowBlur: 0.25
            shadowVerticalOffset: 1
        }

        // Soft top highlight — the glassy sheen catching light.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 9
            anchors.rightMargin: 9
            anchors.topMargin: 1
            height: 1
            radius: 0.5
            color: Qt.rgba(1, 1, 1, 0.18)
        }
    }

    RowLayout {
        id: controlRow
        anchors.centerIn: parent
        spacing: root.dockStyle === "accent" ? 5 : 2

        DockToggle {
            visible: root.showExtras
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            areaName: "shuffleArea"
            available: root.canShuffle
            label: !root.canShuffle ? "Shuffle unavailable for this player" : root.shuffleOn ? "Shuffle on" : "Shuffle off"
            active: root.shuffleOn
            controlColor: root.controlColor
            accentColor: root.accentColor
            iconPath: "M16 3h5v5l-1.8-1.8-4.4 4.4-1.4-1.4 4.4-4.4zM3 5.4 4.4 4 20 19.6 18.6 21zM13.4 14.8l1.4-1.4 4.4 4.4L21 16v5h-5l1.8-1.8z"
            onToggled: root.toggleShuffle()
        }

        // Previous Button
        Item {
            id: prevBtn
            visible: root.showSkip
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            scale: prevArea.pressed ? 0.94 : (prevArea.containsMouse ? 1.07 : 1.0)
            Behavior on scale {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            Canvas {
                id: prevIcon
                anchors.centerIn: parent
                width: 12
                height: 12
                opacity: prevArea.containsMouse ? 1.0 : 0.78
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.controlColor;
                    ctx.beginPath();
                    ctx.moveTo(10, 1.5);
                    ctx.lineTo(1.5, 6);
                    ctx.lineTo(10, 10.5);
                    ctx.closePath();
                    ctx.fill();
                }
                Connections {
                    target: root
                    function onControlColorChanged() {
                        prevIcon.requestPaint();
                    }
                }
            }
            MouseArea {
                id: prevArea
                objectName: "prevArea"
                anchors.fill: parent
                anchors.margins: -2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const p = root.player;
                    if (!p || p.canGoPrevious === false)
                        return;
                    if (p.previous)
                        p.previous();
                    else if (p.Previous)
                        p.Previous();
                }
            }
        }

        // Play/Pause Button
        Item {
            id: playBtn
            readonly property bool accent: root.dockStyle === "accent"
            Layout.preferredWidth: accent ? 24 : 26
            Layout.preferredHeight: accent ? 24 : 22
            scale: playArea.pressed ? 0.94 : (playArea.containsMouse ? 1.06 : 1.0)
            Behavior on scale {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            // Accent style: a round accent button with a dark icon.
            Rectangle {
                anchors.fill: parent
                visible: playBtn.accent
                radius: width / 2
                color: root.accentColor
                layer.enabled: visible && GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.accentColor
                    shadowOpacity: 0.45
                    shadowBlur: 0.35
                    shadowVerticalOffset: 2
                }
            }

            Canvas {
                id: playIcon
                anchors.centerIn: parent
                width: playBtn.accent ? 10 : 12
                height: width
                opacity: playBtn.accent ? 1 : (playArea.containsMouse ? 1.0 : 0.86)
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(width / 12, height / 12);
                    ctx.fillStyle = playBtn.accent ? "#11140f" : root.controlColor;
                    if (root.isPlaying) {
                        // Draw two vertical pause bars
                        ctx.fillRect(2, 1, 3.5, 10);
                        ctx.fillRect(6.5, 1, 3.5, 10);
                    } else {
                        // Draw play triangle
                        ctx.beginPath();
                        ctx.moveTo(2.5, 1);
                        ctx.lineTo(10.5, 6);
                        ctx.lineTo(2.5, 11);
                        ctx.closePath();
                        ctx.fill();
                    }
                }
                onWidthChanged: requestPaint()
                Connections {
                    target: root
                    function onIsPlayingChanged() {
                        playIcon.requestPaint();
                    }
                    function onControlColorChanged() {
                        playIcon.requestPaint();
                    }
                }
            }
            MouseArea {
                id: playArea
                objectName: "playArea"
                anchors.fill: parent
                anchors.margins: -2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const p = root.player;
                    if (!p || p.canTogglePlaying === false)
                        return;
                    if (p.togglePlaying)
                        p.togglePlaying();
                    else if (p.playPause)
                        p.playPause();
                    else if (p.PlayPause)
                        p.PlayPause();
                    else if (root.isPlaying)
                        (p.pause || p.Pause || function () {})();
                    else
                        (p.play || p.Play || function () {})();
                }
            }
        }

        // Next Button
        Item {
            id: nextBtn
            visible: root.showSkip
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            scale: nextArea.pressed ? 0.94 : (nextArea.containsMouse ? 1.07 : 1.0)
            Behavior on scale {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            Canvas {
                id: nextIcon
                anchors.centerIn: parent
                width: 12
                height: 12
                opacity: nextArea.containsMouse ? 1.0 : 0.78
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = root.controlColor;
                    ctx.beginPath();
                    ctx.moveTo(2, 1.5);
                    ctx.lineTo(10.5, 6);
                    ctx.lineTo(2, 10.5);
                    ctx.closePath();
                    ctx.fill();
                }
                Connections {
                    target: root
                    function onControlColorChanged() {
                        nextIcon.requestPaint();
                    }
                }
            }
            MouseArea {
                id: nextArea
                objectName: "nextArea"
                anchors.fill: parent
                anchors.margins: -2
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const p = root.player;
                    if (!p || p.canGoNext === false)
                        return;
                    if (p.next)
                        p.next();
                    else if (p.Next)
                        p.Next();
                }
            }
        }

        DockToggle {
            visible: root.showExtras
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            areaName: "repeatArea"
            available: root.canLoop
            label: !root.canLoop ? "Repeat unavailable for this player" : root.loopTrack ? "Repeat track" : root.loopOn ? "Repeat playlist" : "Repeat off"
            badge: root.loopTrack ? "1" : ""
            active: root.loopOn
            controlColor: root.controlColor
            accentColor: root.accentColor
            iconPath: "M7 7h11V4l4 4-4 4V9H7v4H5V9a2 2 0 0 1 2-2zm10 10H6v3l-4-4 4-4v3h11v-4h2v4a2 2 0 0 1-2 2z"
            onToggled: root.cycleLoop()
        }
    }
}
