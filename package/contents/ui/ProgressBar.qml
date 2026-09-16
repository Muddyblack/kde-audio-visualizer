pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
    id: root
    property var player: null
    property bool isPlaying: false
    property bool hasAudio: false
    property bool playbackActive: true
    property int style: 0
    property string track: ""
    property string artist: ""
    property color textColor: "#ffffff"
    property color waveColor: "#ffffff"
    property color controlColor: "#ffffff"
    property color pgStartColor: "#ffffff"
    property color pgEndColor: "#ffffff"
    property real positionUnitsPerSecond: 0
    property real visualFrameTime: 0
    property bool reducedMotion: false
    property bool showTimes: true
    property string timeFormat: "total"
    property bool centerTimes: false
    // Layouts hide the bar while another element (the cover ring) shows progress.
    property bool suppressed: false
    // Heights follow the HTML `.pb` variants, with and without time labels.
    implicitHeight: style === 9 ? 12 : style === 4 ? (showTimes ? 28 : 19) : style === 5 || style === 7 ? (showTimes ? 18 : 11) : (showTimes ? 18 : 9)
    readonly property string elapsedText: positionClock.elapsedText
    readonly property string totalLabel: timeFormat === "remaining" ? positionClock.remainingText : positionClock.totalText

    // Audio frames advance playback; the clock retains its slow silent fallback.
    onVisualFrameTimeChanged: {
        if (positionClock.active && root.isPlaying)
            positionClock.tick();
    }

    // Visible only if we have a player and a valid track length
    visible: !root.suppressed && !!root.player && lengthValue > 0
    opacity: visible ? 1.0 : 0.0

    readonly property int pbStyle: root.style

    readonly property real lengthValue: positionClock.lengthValue
    readonly property real progress: positionClock.progress
    readonly property int progressPixel: Math.round(positionClock.progress * progressTrack.width)
    readonly property bool animateDecorations: root.isPlaying && root.hasAudio && positionClock.active
    readonly property real sweep: {
        if (!animateDecorations)
            return -0.35;
        const phase = Math.min(1, (root.visualFrameTime % 1730) / 1450);
        return -0.35 + 1.7 * (0.5 - 0.5 * Math.cos(Math.PI * phase));
    }

    PlaybackClock {
        id: positionClock
        objectName: "positionClock"
        unitScale: root.positionUnitsPerSecond
        // Audio frames tick the clock while the waveform moves.
        // A slow fallback keeps silent playback/time labels correct.
        updateInterval: 1000
        player: root.player
        playing: root.isPlaying
        track: root.track
        active: root.visible && root.width > 0 && root.height > 0 && root.playbackActive
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 180
        }
    }

    // ── Style 4 — Android Waveform seekbar ───────────────────
    Canvas {
        id: waveformSeek
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 1
        height: 18
        visible: root.pbStyle === 4
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        // seeded pseudo-random waveform heights, unique per track
        property var barHeights: []
        property int numBars: 0
        property string waveformKey: ""

        function buildWaveform() {
            const w = width;
            if (!visible || w <= 0)
                return;
            const gap = 2;
            const barW = 3;
            const n = Math.floor(w / (barW + gap));
            const key = root.track + "\u0000" + root.artist;
            if (n === numBars && barHeights.length === n && waveformKey === key)
                return;
            numBars = n;
            waveformKey = key;
            // hash track title for a stable seed
            let seed = 0;
            const s = root.track + root.artist;
            for (let c = 0; c < s.length; c++)
                seed = (seed * 31 + s.charCodeAt(c)) >>> 0;
            const heights = [];
            for (let i = 0; i < n; i++) {
                seed = (seed * 1664525 + 1013904223) >>> 0;
                const r = (seed >>> 16) / 65535;
                // shape: taper at edges, random in middle
                const pos = n > 1 ? i / (n - 1) : 0;
                const taper = Math.sin(pos * Math.PI);
                heights.push(0.15 + r * 0.85 * taper);
            }
            barHeights = heights;
            requestPaint();
        }

        Component.onCompleted: buildWaveform()
        onWidthChanged: buildWaveform()
        onHeightChanged: {
            if (visible)
                requestPaint();
        }
        onVisibleChanged: {
            if (visible) {
                buildWaveform();
                requestPaint();
            }
        }
        Connections {
            target: root
            function onTrackChanged() {
                waveformSeek.buildWaveform();
            }
            function onArtistChanged() {
                waveformSeek.buildWaveform();
            }
            function onWaveColorChanged() {
                if (waveformSeek.visible)
                    waveformSeek.requestPaint();
            }
            function onTextColorChanged() {
                if (waveformSeek.visible)
                    waveformSeek.requestPaint();
            }
            function onControlColorChanged() {
                if (waveformSeek.visible)
                    waveformSeek.requestPaint();
            }
        }
        // Repaint when the playhead reaches a new pixel, not on
        // every 50 ms position tick: bars only change colour as
        // the playhead passes them, and on a three-minute track
        // it moves under 2 px a second.
        readonly property int playheadPx: visible ? Math.round(root.progress * width) : 0
        readonly property bool showPlayhead: visible && root.progress > 0 && root.progress < 1
        onPlayheadPxChanged: {
            if (visible)
                requestPaint();
        }
        onShowPlayheadChanged: {
            if (visible)
                requestPaint();
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (barHeights.length === 0)
                return;
            const gap = 2;
            const barW = 3;
            const n = barHeights.length;
            const h = height;
            const playheadX = playheadPx;
            const playedColor = Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.90);
            const unplayedColor = Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25);

            for (let i = 0; i < n; i++) {
                const x = i * (barW + gap);
                const played = (x + barW / 2) < playheadX;
                const bh = played ? Math.max(2, barHeights[i] * h) : Math.max(2, barHeights[i] * h * 0.45);
                const y = (h - bh) / 2;

                ctx.fillStyle = played ? playedColor : unplayedColor;

                const r = barW / 2;
                ctx.beginPath();
                if (bh > r * 2) {
                    ctx.moveTo(x + r, y);
                    ctx.arc(x + r, y + r, r, Math.PI, 0);
                    ctx.lineTo(x + barW, y + bh - r);
                    ctx.arc(x + r, y + bh - r, r, 0, Math.PI);
                    ctx.closePath();
                } else {
                    ctx.arc(x + r, y + bh / 2, r, 0, Math.PI * 2);
                }
                ctx.fill();
            }

            // playhead line
            if (showPlayhead) {
                ctx.fillStyle = Qt.rgba(root.controlColor.r, root.controlColor.g, root.controlColor.b, 0.95);
                const phX = playheadX - 1;
                ctx.fillRect(phX, 0, 2, h);
            }
        }
    }

    // ── Styles 5 (Squiggle) and 7 (Dotted) — HTML drawSeek ──
    Canvas {
        id: lineSeek
        objectName: "lineSeek"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 10
        visible: root.pbStyle === 5 || root.pbStyle === 7
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        // The HTML eases the amplitude each frame; a one-shot transition on
        // play/pause gives the same settle without a permanent animation loop.
        property real amplitude: root.pbStyle === 5 && root.isPlaying && !root.reducedMotion ? 2.2 : 0
        Behavior on amplitude {
            NumberAnimation {
                duration: 450
                easing.type: Easing.OutQuad
            }
        }
        // The wave phase rides audio frames, and only while it is visible.
        readonly property real phase: visible && root.pbStyle === 5 && amplitude > 0 ? root.visualFrameTime / 1000 : 0
        readonly property int playheadPx: visible ? Math.round(root.progress * width) : 0

        function repaint() {
            if (visible)
                requestPaint();
        }
        onAmplitudeChanged: repaint()
        onPhaseChanged: repaint()
        onPlayheadPxChanged: repaint()
        onWidthChanged: repaint()
        onVisibleChanged: repaint()
        Connections {
            target: root
            function onStyleChanged() {
                lineSeek.repaint();
            }
            function onWaveColorChanged() {
                lineSeek.repaint();
            }
            function onTextColorChanged() {
                lineSeek.repaint();
            }
            function onControlColorChanged() {
                lineSeek.repaint();
            }
            function onPgStartColorChanged() {
                lineSeek.repaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height, px = playheadPx;
            if (w <= 0)
                return;
            if (root.pbStyle === 5) {
                ctx.lineWidth = 2;
                ctx.lineCap = "round";
                ctx.strokeStyle = root.pgStartColor;
                ctx.beginPath();
                for (let x = 1; x <= px; x += 1) {
                    const y = h / 2 + Math.sin(x * 0.38 - phase * 6) * amplitude;
                    if (x > 1)
                        ctx.lineTo(x, y);
                    else
                        ctx.moveTo(x, y);
                }
                ctx.stroke();
                ctx.strokeStyle = Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25);
                ctx.beginPath();
                ctx.moveTo(Math.min(w - 1, px + 5), h / 2);
                ctx.lineTo(w - 1, h / 2);
                ctx.stroke();
                ctx.fillStyle = root.controlColor;
                ctx.beginPath();
                ctx.roundedRect(px - 1.5, 0, 3, h, 1.5, 1.5);
                ctx.fill();
            } else {
                // Dots of one colour share a path; the raster matches per-dot fills.
                for (const played of [true, false]) {
                    ctx.beginPath();
                    const r = played ? 1.6 : 1.1;
                    for (let x = 3; x < w; x += 6) {
                        if ((x < px) !== played)
                            continue;
                        ctx.moveTo(x + r, h / 2);
                        ctx.arc(x, h / 2, r, 0, Math.PI * 2);
                    }
                    ctx.fillStyle = played ? root.waveColor : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.3);
                    ctx.fill();
                }
                ctx.fillStyle = root.controlColor;
                ctx.beginPath();
                ctx.arc(Math.max(3, Math.min(w - 3, px)), h / 2, 3.2, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    Rectangle {
        id: progressTrack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.pbStyle === 1 ? 4 : root.pbStyle === 8 ? 3 : 2
        visible: root.pbStyle !== 4 && root.pbStyle !== 5 && root.pbStyle !== 7 && root.pbStyle !== 9
        height: root.pbStyle === 1 ? 1 : root.pbStyle === 2 || root.pbStyle === 6 ? (pbArea.containsMouse ? (root.pbStyle === 6 ? 5 : 6) : 4) : root.pbStyle === 3 ? (pbArea.containsMouse ? 8 : 6) : root.pbStyle === 8 ? (pbArea.containsMouse ? 6 : 5) : (pbArea.containsMouse ? 5 : 3)
        radius: height / 2
        color: root.pbStyle === 6 ? "transparent" : root.pbStyle === 1 ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: root.pbStyle === 1 || root.pbStyle === 6 ? 0 : 1

        Behavior on height {
            NumberAnimation {
                duration: 150
            }
        }

        // Style 6 — Segmented: 7 px segments, 2 px gaps; the track's rounded
        // ends clip its first and last segment as the HTML background does.
        readonly property int segmentCount: Math.ceil(width / 9)
        Repeater {
            model: root.pbStyle === 6 ? progressTrack.segmentCount : 0
            Rectangle {
                required property int index
                readonly property real segmentEnd: Math.min(progressTrack.width, index * 9 + 7)
                x: index * 9
                width: Math.max(0, segmentEnd - x)
                height: progressTrack.height
                color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.18)
                topLeftRadius: index === 0 ? progressTrack.radius : 0
                bottomLeftRadius: topLeftRadius
                topRightRadius: segmentEnd >= progressTrack.width ? progressTrack.radius : 0
                bottomRightRadius: topRightRadius
            }
        }

        Item {
            id: progressFillClip
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // A subpixel playhead change does not need a new frame.
            width: root.progressPixel
            clip: true
            // Style 0,2,3 — gradient fill
            Rectangle {
                anchors.fill: parent
                radius: progressTrack.radius
                visible: root.pbStyle !== 1 && root.pbStyle !== 6 && root.pbStyle !== 8
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.pgStartColor.r, root.pgStartColor.g, root.pgStartColor.b, 0.62)
                    }
                    GradientStop {
                        position: 0.65
                        color: Qt.rgba(root.pgStartColor.r, root.pgStartColor.g, root.pgStartColor.b, 0.95)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.pgEndColor.r, root.pgEndColor.g, root.pgEndColor.b, 0.82)
                    }
                }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.pgStartColor
                    shadowOpacity: root.pbStyle === 2 ? (root.isPlaying ? 0.65 : 0.35) : (root.isPlaying ? 0.38 : 0.18)
                    shadowBlur: root.pbStyle === 2 ? 0.45 : 0.28
                }
            }

            // Style 1 — flat solid fill (Ultra Minimal)
            Rectangle {
                anchors.fill: parent
                radius: progressTrack.radius
                visible: root.pbStyle === 1
                color: Qt.rgba(root.pgStartColor.r, root.pgStartColor.g, root.pgStartColor.b, 0.75)
            }

            // Style 8 — Capsule: solid fill without glow.
            Rectangle {
                anchors.fill: parent
                radius: progressTrack.radius
                visible: root.pbStyle === 8
                color: root.pgStartColor
            }

            // Style 6 — Segmented fill, square-ended like the HTML fill.
            Repeater {
                model: root.pbStyle === 6 ? progressTrack.segmentCount : 0
                Rectangle {
                    required property int index
                    x: index * 9
                    width: 7
                    height: progressTrack.height
                    color: root.pgStartColor
                }
            }

            Rectangle {
                width: Math.max(18, progressTrack.width * 0.22)
                height: parent.height
                radius: parent.height / 2
                x: (progressFillClip.width + width) * root.sweep - width
                opacity: (root.isPlaying && (root.pbStyle === 0 || root.pbStyle === 2)) ? 0.72 : 0.0
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(root.controlColor.r, root.controlColor.g, root.controlColor.b, 0.0)
                    }
                    GradientStop {
                        position: 0.50
                        color: Qt.rgba(root.controlColor.r, root.controlColor.g, root.controlColor.b, 0.78)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(root.controlColor.r, root.controlColor.g, root.controlColor.b, 0.0)
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }
            }
        }

        Rectangle {
            width: root.pbStyle === 2 ? (pbArea.containsMouse ? 10 : 8) : (pbArea.containsMouse ? 8 : 6)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, root.progressPixel - width / 2))
            color: Qt.rgba(root.controlColor.r, root.controlColor.g, root.controlColor.b, root.isPlaying ? 0.95 : 0.68)
            opacity: ((root.pbStyle === 0 || root.pbStyle === 2) && root.progress > 0) ? 1.0 : 0.0
            layer.enabled: root.pbStyle === 0 || root.pbStyle === 2
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: root.pgStartColor
                shadowOpacity: root.pbStyle === 2 ? (root.isPlaying ? 0.75 : 0.42) : (root.isPlaying ? 0.55 : 0.22)
                shadowBlur: root.pbStyle === 2 ? 0.60 : 0.40
            }

            scale: root.animateDecorations && (root.pbStyle === 0 || root.pbStyle === 2) ? 1.05 - 0.13 * Math.cos(2 * Math.PI * (root.visualFrameTime % 1400) / 1400) : 1
        }

        // Style 8 — white capsule knob with a small drop shadow.
        Rectangle {
            objectName: "capsuleKnob"
            visible: root.pbStyle === 8
            width: 16
            height: 9
            radius: 4.5
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, root.progressPixel - width / 2))
            color: "#ffffff"
            border.width: 0.5
            border.color: Qt.rgba(0, 0, 0, 0x22 / 255)
            // The software scene graph cannot draw MultiEffect; keep the knob there.
            layer.enabled: visible && GraphicsInfo.api !== GraphicsInfo.Software
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.4
                shadowBlur: 0.25
                shadowVerticalOffset: 1
            }
        }
    }

    Text {

        renderType: Text.CurveRendering ?? Text.QtRendering
        objectName: "elapsedTimeLabel"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        visible: root.showTimes && root.pbStyle !== 9
        text: positionClock.elapsedText
        color: root.textColor
        opacity: 0.50
        font.pixelSize: 8
    }

    Text {

        renderType: Text.CurveRendering ?? Text.QtRendering
        objectName: "totalTimeLabel"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.showTimes && root.pbStyle !== 9
        text: root.totalLabel
        color: root.textColor
        opacity: 0.50
        font.pixelSize: 8
    }

    // Style 9 — Time only: "1:31 / 3:58", always shown, centred with centred text.
    Row {
        objectName: "timeOnlyRow"
        visible: root.pbStyle === 9
        anchors.top: parent.top
        anchors.left: root.centerTimes ? undefined : parent.left
        anchors.horizontalCenter: root.centerTimes ? parent.horizontalCenter : undefined
        spacing: 4
        opacity: 0.65

        Row {
            Text {
                renderType: Text.CurveRendering ?? Text.QtRendering
                objectName: "timeOnlyElapsed"
                text: positionClock.elapsedText
                color: root.textColor
                font.pixelSize: 9
            }
            Text {
                renderType: Text.CurveRendering ?? Text.QtRendering
                text: " /"
                color: root.textColor
                opacity: 0.6
                font.pixelSize: 9
            }
        }
        Text {
            renderType: Text.CurveRendering ?? Text.QtRendering
            objectName: "timeOnlyTotal"
            text: root.totalLabel
            color: root.textColor
            font.pixelSize: 9
        }
    }

    MouseArea {
        id: pbArea
        objectName: "pbArea"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            const ratio = progressTrack.width > 0 ? (mouse.x - progressTrack.x) / progressTrack.width : 0;
            positionClock.seekToFraction(ratio);
        }
    }
}
