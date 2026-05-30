import QtQuick 2.15
import QtQuick.Layouts 1.1
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    Layout.minimumWidth: plasmoid.configuration.showMpris ? 260 : 160
    Layout.minimumHeight: 64
    Layout.preferredWidth: plasmoid.configuration.showMpris ? 360 : 200
    Layout.preferredHeight: plasmoid.configuration.showMpris ? 104 : 84

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    readonly property string artist: mpris2Model.currentPlayer?.artist ?? ""
    readonly property string track: mpris2Model.currentPlayer?.track ?? ""
    readonly property int playbackStatus: mpris2Model.currentPlayer?.playbackStatus ?? 0
    readonly property bool isPlaying: playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool hasPlayer: !!mpris2Model.currentPlayer
    readonly property color accentColor: Kirigami.Theme.highlightColor
    readonly property color textColor: plasmoid.configuration.useSystemText ? Kirigami.Theme.textColor : plasmoid.configuration.customTextColor
    readonly property color waveColor: plasmoid.configuration.useSystemAccent ? accentColor : plasmoid.configuration.customColor
    readonly property color controlColor: plasmoid.configuration.useSystemControls ? "#ffffff" : plasmoid.configuration.customControlColor
    readonly property color pgStartColor: plasmoid.configuration.useSystemControls ? accentColor : controlColor
    readonly property color pgEndColor: plasmoid.configuration.useSystemControls ? "#ffffff" : controlColor

    readonly property string desktopEntry: mpris2Model.currentPlayer?.desktopEntry ?? ""

    property string artUrl: ""
    readonly property string _rawArtUrl: mpris2Model.currentPlayer?.artUrl ?? ""
    on_RawArtUrlChanged: if (_rawArtUrl !== "" && plasmoid.configuration.showMpris)
        artUrl = _rawArtUrl
    Connections {
        target: plasmoid.configuration
        ignoreUnknownSignals: true
        function onShowMprisChanged() {
            if (!plasmoid.configuration.showMpris)
                root.artUrl = "";
        }
    }

    // Cava always runs — wave reacts to whatever's playing system-wide,
    // independent of whether MPRIS players are reporting state correctly.
    Visualizer {
        id: vis
        active: true
    }

    fullRepresentation: Item {
        id: container
        // No clip — clipping cuts off text when background card is enabled

        // ── Background card source (rendered offscreen, used by backgroundCardEffect) ──
        // Art image source — must be a sibling, not child of backgroundCard
        Image {
            id: bgArtImg
            anchors.fill: parent
            source: (plasmoid.configuration.showMpris && plasmoid.configuration.artBg) ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        Rectangle {
            id: backgroundCard
            anchors.fill: parent
            visible: false
            radius: plasmoid.configuration.bgRadius
            color: "transparent"
            clip: true

            // Blurred art fill — only when artBg is enabled and art is loaded
            MultiEffect {
                anchors.fill: parent
                source: bgArtImg
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 0.3
                brightness: -0.25
                opacity: (plasmoid.configuration.artBg && bgArtImg.status === Image.Ready) ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 400
                    }
                }
            }

            // Flat color — dark tint over art, or solid bgColor when art bg is off
            Rectangle {
                anchors.fill: parent
                color: (plasmoid.configuration.artBg && bgArtImg.status === Image.Ready) ? Qt.rgba(0, 0, 0, 0.35) : plasmoid.configuration.bgColor
                Behavior on color {
                    ColorAnimation {
                        duration: 400
                    }
                }
            }

            // Border on top
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: plasmoid.configuration.bgRadius
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
            }
        }

        MultiEffect {
            id: backgroundCardEffect
            anchors.fill: parent
            source: backgroundCard
            visible: plasmoid.configuration.showBg

            maskEnabled: plasmoid.configuration.cutBg
            maskSource: maskWrapper
            maskInverted: true
        }

        Item {
            id: maskWrapper
            anchors.fill: parent
            visible: false

            Canvas {
                id: waveMask
                x: wave.x + (wave.parent ? wave.parent.x : 0) + (wave.parent && wave.parent.parent ? wave.parent.parent.x : 0)
                y: wave.y + (wave.parent ? wave.parent.y : 0) + (wave.parent && wave.parent.parent ? wave.parent.parent.y : 0)
                width: wave.width
                height: wave.height
                antialiasing: true
                renderStrategy: Canvas.Cooperative

                // Only repaint the mask while the cut-out effect is actually
                // live (showBg + cutBg). Otherwise this Canvas + its MultiEffect
                // re-render every frame feeding a mask nothing consumes.
                readonly property bool maskActive: plasmoid.configuration.showBg && plasmoid.configuration.cutBg
                Connections {
                    target: vis
                    function onBarsChanged() {
                        if (waveMask.maskActive)
                            waveMask.requestPaint();
                    }
                }
                Connections {
                    target: root
                    function onIsPlayingChanged() {
                        if (waveMask.maskActive)
                            waveMask.requestPaint();
                    }
                }
                // Repaint once when the effect is toggled on so the mask is fresh.
                Connections {
                    target: plasmoid.configuration
                    ignoreUnknownSignals: true
                    function onCutBgChanged() {
                        waveMask.requestPaint();
                    }
                    function onShowBgChanged() {
                        waveMask.requestPaint();
                    }
                }

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (!root.isPlaying)
                        return;
                    const mid = height / 2;
                    const n = vis.numBars;
                    const step = width / (n - 1);
                    const amp = height * 0.42;

                    function getTaper(i, total) {
                        const pos = i / (total - 1);
                        const edge = 0.15;
                        if (pos < edge) {
                            const w = pos / edge;
                            return 0.5 - 0.5 * Math.cos(w * Math.PI);
                        } else if (pos > 1.0 - edge) {
                            const w = (1.0 - pos) / edge;
                            return 0.5 - 0.5 * Math.cos(w * Math.PI);
                        }
                        return 1.0;
                    }

                    function plot(sign) {
                        ctx.beginPath();
                        let prevX = 0;
                        let prevY = mid + sign * ((vis.bars[0] || 0) / vis.maxRange) * amp * getTaper(0, n);
                        ctx.moveTo(prevX, prevY);
                        for (let i = 1; i < n; i++) {
                            const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                            const x = i * step;
                            const y = mid + sign * v * amp;
                            const cpX = (prevX + x) / 2;
                            ctx.bezierCurveTo(cpX, prevY, cpX, y, x, y);
                            prevX = x;
                            prevY = y;
                        }
                        ctx.lineTo(width, mid);
                        ctx.lineTo(0, mid);
                        ctx.closePath();
                        ctx.fillStyle = "black";
                        ctx.fill();
                    }
                    plot(-1);
                    plot(1);
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: plasmoid.configuration.showBg ? 10 : 0
            anchors.rightMargin: plasmoid.configuration.showBg ? 10 : 0
            anchors.topMargin: plasmoid.configuration.showBg ? 4 : 0
            anchors.bottomMargin: 0
            spacing: plasmoid.configuration.showMpris ? 12 : 0

            // ── Album art and controls ────────────────────────────────────────
            ColumnLayout {
                id: artColumn
                spacing: 4
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                visible: plasmoid.configuration.showMpris

                Item {
                    id: artBox
                    Layout.fillHeight: true
                    Layout.maximumHeight: 72
                    Layout.preferredWidth: Math.min(artBox.height, 72)
                    Layout.maximumWidth: 72
                    Layout.alignment: Qt.AlignHCenter
                    width: Math.min(height, 72)

                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: root.desktopEntry !== "" ? root.desktopEntry : "audio-x-generic-symbolic"
                        width: root.desktopEntry !== "" ? parent.width * 0.72 : parent.width * 0.45
                        height: width
                        opacity: root.desktopEntry !== "" ? 0.70 : 0.35
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                            }
                        }
                    }

                    Image {
                        id: artImg
                        anchors.fill: parent
                        source: plasmoid.configuration.showMpris ? root.artUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        visible: false
                    }

                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: 10
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: artImg
                        maskEnabled: true
                        maskSource: artMask
                        opacity: (artImg.status === Image.Ready || artImg.status === Image.Loading) ? 1.0 : 0.0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 400
                            }
                        }
                    }
                }

                // ── Glassy transport dock ─────────────────────────────────────
                Item {
                    id: controlDock
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 26
                    visible: root.hasPlayer

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        // Use custom dock bg color when not using system default
                        color: plasmoid.configuration.useSystemDockBg ? Qt.rgba(1, 1, 1, 0.09) : plasmoid.configuration.customDockBgColor
                        border.color: Qt.rgba(1, 1, 1, 0.22)
                        border.width: 1

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.25)
                            shadowOpacity: 0.3
                            shadowBlur: 0.2
                            shadowVerticalOffset: 1
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 1
                            height: 1
                            radius: 0.5
                            color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }

                    RowLayout {
                        id: controlRow
                        anchors.centerIn: parent
                        spacing: 2

                        // Previous Button
                        Item {
                            id: prevBtn
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
                                anchors.fill: parent
                                anchors.margins: -2
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const p = mpris2Model.currentPlayer;
                                    if (!p)
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
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 22
                            scale: playArea.pressed ? 0.94 : (playArea.containsMouse ? 1.06 : 1.0)
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 130
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Canvas {
                                id: playIcon
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                opacity: playArea.containsMouse ? 1.0 : 0.86
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.fillStyle = root.controlColor;
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
                                anchors.fill: parent
                                anchors.margins: -2
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const p = mpris2Model.currentPlayer;
                                    if (!p)
                                        return;
                                    if (p.playPause)
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
                                anchors.fill: parent
                                anchors.margins: -2
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const p = mpris2Model.currentPlayer;
                                    if (!p)
                                        return;
                                    if (p.next)
                                        p.next();
                                    else if (p.Next)
                                        p.Next();
                                }
                            }
                        }
                    }
                }
            }

            // ── Waveform + text ───────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Canvas {
                    id: wave
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.maximumHeight: 44
                    antialiasing: true
                    renderStrategy: Canvas.Cooperative

                    Connections {
                        target: vis
                        function onBarsChanged() {
                            wave.requestPaint();
                        }
                    }
                    Connections {
                        target: root
                        function onIsPlayingChanged() {
                            wave.requestPaint();
                        }
                        function onWaveColorChanged() {
                            wave.requestPaint();
                        }
                    }
                    Connections {
                        target: plasmoid.configuration
                        ignoreUnknownSignals: true
                        function onLineWidthChanged() {
                            wave.requestPaint();
                        }
                        function onFillWaveChanged() {
                            wave.requestPaint();
                        }
                        function onGlowWaveChanged() {
                            wave.requestPaint();
                        }
                        function onCutBgChanged() {
                            wave.requestPaint();
                        }
                        function onVisualizerTypeChanged() {
                            wave.requestPaint();
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";

                        const mid = height / 2;
                        const n = vis.numBars;
                        const vtype = plasmoid.configuration.visualizerType;

                        // ── Idle line (all visualizer types) ──────────────────
                        if (!root.isPlaying) {
                            ctx.lineWidth = 1.2;
                            ctx.strokeStyle = Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.35);
                            ctx.beginPath();
                            ctx.moveTo(2, mid);
                            ctx.lineTo(width - 2, mid);
                            ctx.stroke();
                            return;
                        }

                        // ── Shared glow setup ─────────────────────────────────
                        const doGlow = plasmoid.configuration.glowWave;
                        if (doGlow) {
                            ctx.shadowBlur = 8;
                            ctx.shadowColor = root.waveColor;
                        } else {
                            ctx.shadowBlur = 0;
                        }

                        // ─────────────────────────────────────────────────────
                        // Helper: cosine-taper so bars/waves fade at the edges
                        // ─────────────────────────────────────────────────────
                        function getTaper(i, total) {
                            const pos = i / (total - 1);
                            const edge = 0.15;
                            if (pos < edge) {
                                const w = pos / edge;
                                return 0.5 - 0.5 * Math.cos(w * Math.PI);
                            } else if (pos > 1.0 - edge) {
                                const w = (1.0 - pos) / edge;
                                return 0.5 - 0.5 * Math.cos(w * Math.PI);
                            }
                            return 1.0;
                        }

                        // ═════════════════════════════════════════════════════
                        // TYPE 0 — Smooth Wave (mirrored bezier)
                        // ═════════════════════════════════════════════════════
                        if (vtype === 0) {
                            const step0 = width / (n - 1);
                            ctx.lineWidth = plasmoid.configuration.lineWidth;
                            ctx.strokeStyle = root.waveColor;

                            function plot0(sign) {
                                ctx.beginPath();
                                const amp = height * 0.42;
                                let prevX = 0;
                                let prevY = mid + sign * ((vis.bars[0] || 0) / vis.maxRange) * amp * getTaper(0, n);
                                ctx.moveTo(prevX, prevY);
                                for (let i = 1; i < n; i++) {
                                    const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                                    const x = i * step0;
                                    const y = mid + sign * v * amp;
                                    const cpX = (prevX + x) / 2;
                                    ctx.bezierCurveTo(cpX, prevY, cpX, y, x, y);
                                    prevX = x;
                                    prevY = y;
                                }
                                ctx.stroke();

                                const isCut = plasmoid.configuration.showBg && plasmoid.configuration.cutBg;
                                if (plasmoid.configuration.fillWave && !isCut) {
                                    ctx.shadowBlur = 0;
                                    ctx.lineTo(width, mid);
                                    ctx.lineTo(0, mid);
                                    ctx.closePath();
                                    const grad = ctx.createLinearGradient(0, mid, 0, mid + sign * amp);
                                    const c1 = Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.38);
                                    const c2 = Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.02);
                                    grad.addColorStop(0.0, c1);
                                    grad.addColorStop(1.0, c2);
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                    if (doGlow) {
                                        ctx.shadowBlur = 8;
                                        ctx.shadowColor = root.waveColor;
                                    }
                                }
                            }
                            plot0(-1);
                            plot0(1);

                            // ═════════════════════════════════════════════════════
                            // TYPE 1 — Rounded Bars (upward bars from bottom)
                            // ═════════════════════════════════════════════════════
                        } else if (vtype === 1) {
                            const totalW = width;
                            const gap = Math.max(1, totalW / n * 0.25);
                            const barW = Math.max(1, totalW / n - gap);
                            const r = barW / 2;
                            const amp1 = height * 0.88;
                            ctx.lineWidth = 0;
                            ctx.strokeStyle = "transparent";

                            for (let i = 0; i < n; i++) {
                                const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                                const bh = Math.max(2, v * amp1);
                                const x = i * (barW + gap) + gap / 2;
                                const y = height - bh;

                                // gradient fill per bar
                                const g = ctx.createLinearGradient(0, y, 0, height);
                                g.addColorStop(0.0, Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.95));
                                g.addColorStop(1.0, Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.35));
                                ctx.fillStyle = g;

                                // rounded-top rectangle
                                ctx.beginPath();
                                if (bh > r * 2) {
                                    ctx.moveTo(x + r, y);
                                    ctx.arc(x + r, y + r, r, Math.PI, 0);
                                    ctx.lineTo(x + barW, height);
                                    ctx.lineTo(x, height);
                                    ctx.closePath();
                                } else {
                                    ctx.arc(x + r, y + r, r, 0, Math.PI * 2);
                                }
                                ctx.fill();
                            }

                            // ═════════════════════════════════════════════════════
                            // TYPE 2 — Mirror Bars (bars grow from centre up & down)
                            // ═════════════════════════════════════════════════════
                        } else if (vtype === 2) {
                            const totalW2 = width;
                            const gap2 = Math.max(1, totalW2 / n * 0.22);
                            const barW2 = Math.max(1, totalW2 / n - gap2);
                            const r2 = barW2 / 2;
                            const amp2 = height * 0.44;

                            for (let i = 0; i < n; i++) {
                                const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                                const bh = Math.max(2, v * amp2);
                                const x = i * (barW2 + gap2) + gap2 / 2;

                                const g2 = ctx.createLinearGradient(0, mid - bh, 0, mid + bh);
                                g2.addColorStop(0.0, Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.35));
                                g2.addColorStop(0.5, Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.95));
                                g2.addColorStop(1.0, Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.35));
                                ctx.fillStyle = g2;

                                // top half
                                ctx.beginPath();
                                if (bh > r2) {
                                    ctx.moveTo(x, mid);
                                    ctx.lineTo(x, mid - bh + r2);
                                    ctx.arc(x + r2, mid - bh + r2, r2, Math.PI, 0);
                                    ctx.lineTo(x + barW2, mid);
                                    ctx.closePath();
                                } else {
                                    ctx.arc(x + r2, mid - r2, r2, 0, Math.PI * 2);
                                }
                                ctx.fill();

                                // bottom half
                                ctx.beginPath();
                                if (bh > r2) {
                                    ctx.moveTo(x, mid);
                                    ctx.lineTo(x, mid + bh - r2);
                                    ctx.arc(x + r2, mid + bh - r2, r2, Math.PI, 2 * Math.PI);
                                    ctx.lineTo(x + barW2, mid);
                                    ctx.closePath();
                                } else {
                                    ctx.arc(x + r2, mid + r2, r2, 0, Math.PI * 2);
                                }
                                ctx.fill();
                            }

                            // ═════════════════════════════════════════════════════
                            // TYPE 3 — Tech Line (stepped segments with node dots)
                            // ═════════════════════════════════════════════════════
                        } else if (vtype === 3) {
                            const step3 = width / (n - 1);
                            const amp3 = height * 0.42;
                            ctx.lineWidth = plasmoid.configuration.lineWidth;
                            ctx.strokeStyle = root.waveColor;

                            function drawTechLine(sign) {
                                ctx.beginPath();
                                for (let i = 0; i < n; i++) {
                                    const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                                    const x = i * step3;
                                    const y = mid + sign * v * amp3;
                                    if (i === 0) {
                                        ctx.moveTo(x, y);
                                    } else {
                                        // horizontal then vertical — oscilloscope step look
                                        const prevX = (i - 1) * step3;
                                        ctx.lineTo(x - step3 * 0.5, mid + sign * ((vis.bars[i - 1] || 0) / vis.maxRange) * getTaper(i - 1, n) * amp3);
                                        ctx.lineTo(x - step3 * 0.5, y);
                                        ctx.lineTo(x, y);
                                    }
                                }
                                ctx.stroke();

                                // node dots at each sample
                                ctx.shadowBlur = doGlow ? 6 : 0;
                                for (let i = 0; i < n; i++) {
                                    const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                                    const x = i * step3;
                                    const y = mid + sign * v * amp3;
                                    ctx.beginPath();
                                    ctx.arc(x, y, 1.6, 0, Math.PI * 2);
                                    ctx.fillStyle = root.waveColor;
                                    ctx.fill();
                                }
                                if (doGlow)
                                    ctx.shadowBlur = 8;
                            }
                            drawTechLine(-1);
                            drawTechLine(1);

                            // ═════════════════════════════════════════════════════
                            // TYPE 4 — Floating Dots (soft radial blobs, lineWidth scales size)
                            // ═════════════════════════════════════════════════════
                        } else if (vtype === 4) {
                            const step4 = width / n;
                            const amp4 = height * 0.42;
                            // lineWidth (1–8) scales how big the dots get
                            const maxR = Math.max(2, step4 * 0.28 * (plasmoid.configuration.lineWidth / 2.0));

                            for (let i = 0; i < n; i++) {
                                const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                                const cx = i * step4 + step4 / 2;
                                const dotR = Math.max(1.5, v * maxR);

                                function drawDot4(cy) {
                                    // solid bright core so it's always visible
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, dotR * 0.45, 0, Math.PI * 2);
                                    ctx.fillStyle = Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.92);
                                    ctx.fill();
                                    // soft glow halo
                                    const grad = ctx.createRadialGradient(cx, cy, dotR * 0.3, cx, cy, dotR);
                                    grad.addColorStop(0.0, Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.55));
                                    grad.addColorStop(1.0, Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.0));
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, dotR, 0, Math.PI * 2);
                                    ctx.fillStyle = grad;
                                    ctx.fill();
                                }

                                drawDot4(mid - v * amp4);
                                drawDot4(mid + v * amp4);
                            }

                            // ═════════════════════════════════════════════════════
                            // TYPE 5 — Floating Dots Bold (outlined rings, high-contrast)
                            // ═════════════════════════════════════════════════════
                        } else if (vtype === 5) {
                            const step5 = width / n;
                            const amp5 = height * 0.42;
                            const maxR5 = Math.max(2, step5 * 0.32);
                            const strokeW = Math.max(0.8, plasmoid.configuration.lineWidth * 0.6);

                            for (let i = 0; i < n; i++) {
                                const v = ((vis.bars[i] || 0) / vis.maxRange) * getTaper(i, n);
                                const cx = i * step5 + step5 / 2;
                                const dotR = Math.max(1.5, v * maxR5);

                                function drawRing(cy) {
                                    // filled center (always punchy)
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, Math.max(0.8, dotR * 0.38), 0, Math.PI * 2);
                                    ctx.fillStyle = Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 1.0);
                                    ctx.fill();
                                    // outer ring stroke
                                    ctx.beginPath();
                                    ctx.arc(cx, cy, dotR, 0, Math.PI * 2);
                                    ctx.strokeStyle = Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.75);
                                    ctx.lineWidth = strokeW;
                                    ctx.stroke();
                                }

                                drawRing(mid - v * amp5);
                                drawRing(mid + v * amp5);
                            }
                        }
                    }
                }

                // ── Seekable progress pulse ──────────────────────────────────
                Item {
                    id: progressBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: progressBar.pbStyle === 4 ? 28 : 18
                    Layout.topMargin: 1
                    Layout.bottomMargin: 1

                    // Visible only if we have a player and a valid track length
                    visible: root.hasPlayer && lengthValue > 0
                    opacity: visible ? 1.0 : 0.0

                    readonly property int pbStyle: plasmoid.configuration.progressBarStyle ?? 0

                    property real lengthValue: playerLength()
                    property real displayedPosition: 0
                    property real anchorPosition: 0
                    property real anchorMs: Date.now()
                    property real progress: lengthValue > 0 ? clamp(displayedPosition / lengthValue, 0, 1) : 0
                    property real sweep: -0.35
                    readonly property string elapsedText: formatTime(displayedPosition)
                    readonly property string totalText: formatTime(lengthValue)

                    function clamp(value, min, max) {
                        return Math.max(min, Math.min(max, value));
                    }

                    function playerLength() {
                        const p = mpris2Model.currentPlayer;
                        if (!p)
                            return 0;
                        return Math.max(0, p.length || p.mprisLength || 0);
                    }

                    function playerPosition() {
                        const p = mpris2Model.currentPlayer;
                        if (!p)
                            return 0;
                        return clamp(p.position || 0, 0, lengthValue);
                    }

                    function unitsPerSecond() {
                        if (lengthValue >= 1000000)
                            return 1000000;
                        if (lengthValue >= 10000)
                            return 1000;
                        return 1;
                    }

                    function predictedPosition() {
                        if (!root.isPlaying)
                            return anchorPosition;
                        const elapsedMs = Date.now() - anchorMs;
                        return clamp(anchorPosition + elapsedMs * unitsPerSecond() / 1000, 0, lengthValue);
                    }

                    function syncFromPlayer(hard) {
                        const len = playerLength();
                        // don't zero out a valid length on a transient 0 while player is present
                        if (len > 0 || !root.hasPlayer)
                            lengthValue = len;

                        if (len <= 0) {
                            if (!root.hasPlayer) {
                                displayedPosition = 0;
                                anchorPosition = 0;
                                anchorMs = Date.now();
                            }
                            return;
                        }

                        const rawPosition = playerPosition();
                        const predicted = predictedPosition();
                        const drift = Math.abs(rawPosition - predicted);
                        const seekSizedDrift = drift > unitsPerSecond() * 1.25;

                        anchorPosition = rawPosition;
                        anchorMs = Date.now();

                        if (hard || seekSizedDrift || !root.isPlaying || displayedPosition <= 0) {
                            displayedPosition = rawPosition;
                        }
                    }

                    function tick() {
                        const len = playerLength();
                        // only shrink lengthValue to 0 if player is truly gone, not on transient 0
                        if (len > 0 || !root.hasPlayer) {
                            if (len !== lengthValue)
                                lengthValue = len;
                        }
                        if (lengthValue <= 0)
                            return;
                        displayedPosition = predictedPosition();
                    }

                    function twoDigits(value) {
                        return value < 10 ? "0" + value : "" + value;
                    }

                    function formatTime(value) {
                        const seconds = Math.max(0, Math.floor(value / unitsPerSecond()));
                        const hours = Math.floor(seconds / 3600);
                        const minutes = Math.floor((seconds % 3600) / 60);
                        const secs = seconds % 60;
                        if (hours > 0) {
                            return hours + ":" + twoDigits(minutes) + ":" + twoDigits(secs);
                        }
                        return minutes + ":" + twoDigits(secs);
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 180
                        }
                    }

                    Component.onCompleted: syncFromPlayer(true)

                    Connections {
                        target: root
                        function onIsPlayingChanged() {
                            progressBar.syncFromPlayer(true);
                        }
                        function onTrackChanged() {
                            progressBar.syncFromPlayer(true);
                        }
                        function onHasPlayerChanged() {
                            progressBar.syncFromPlayer(true);
                        }
                    }

                    Connections {
                        target: mpris2Model.currentPlayer
                        ignoreUnknownSignals: true
                        function onPositionChanged() {
                            progressBar.syncFromPlayer(false);
                        }
                        function onLengthChanged() {
                            progressBar.syncFromPlayer(true);
                        }
                        function onMprisLengthChanged() {
                            progressBar.syncFromPlayer(true);
                        }
                    }

                    // Only predict position while actually playing. While paused
                    // the position is static, and onIsPlayingChanged re-syncs the
                    // displayed position, so a 20fps tick here just keeps the
                    // shared render/event loop needlessly warm.
                    Timer {
                        interval: 50
                        running: root.hasPlayer && root.isPlaying
                        repeat: true
                        onTriggered: progressBar.tick()
                    }

                    SequentialAnimation on sweep {
                        running: root.isPlaying && progressBar.visible && (progressBar.pbStyle === 0 || progressBar.pbStyle === 2)
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -0.35
                            to: 1.35
                            duration: 1450
                            easing.type: Easing.InOutSine
                        }
                        PauseAnimation {
                            duration: 280
                        }
                    }

                    // ── Style 4 — Android Waveform seekbar ───────────────────
                    Canvas {
                        id: waveformSeek
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 1
                        height: parent.height - 10
                        visible: progressBar.pbStyle === 4
                        antialiasing: true
                        renderStrategy: Canvas.Cooperative

                        // seeded pseudo-random waveform heights, unique per track
                        property var barHeights: []
                        property int numBars: 0

                        function buildWaveform() {
                            const w = width;
                            if (w <= 0)
                                return;
                            const gap = 2;
                            const barW = 3;
                            const n = Math.floor(w / (barW + gap));
                            if (n === numBars && barHeights.length === n)
                                return;
                            numBars = n;
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
                                const pos = i / (n - 1);
                                const taper = Math.sin(pos * Math.PI);
                                heights.push(0.15 + r * 0.85 * taper);
                            }
                            barHeights = heights;
                            requestPaint();
                        }

                        Component.onCompleted: buildWaveform()
                        onWidthChanged: {
                            numBars = 0;
                            buildWaveform();
                        }
                        Connections {
                            target: root
                            function onTrackChanged() {
                                waveformSeek.numBars = 0;
                                waveformSeek.buildWaveform();
                            }
                            function onArtistChanged() {
                                waveformSeek.numBars = 0;
                                waveformSeek.buildWaveform();
                            }
                            function onWaveColorChanged() {
                                waveformSeek.requestPaint();
                            }
                        }
                        Connections {
                            target: progressBar
                            function onProgressChanged() {
                                waveformSeek.requestPaint();
                            }
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
                            const prog = progressBar.progress;
                            const playheadX = prog * width;

                            for (let i = 0; i < n; i++) {
                                const x = i * (barW + gap);
                                const played = (x + barW / 2) < playheadX;
                                const bh = played ? Math.max(2, barHeights[i] * h) : Math.max(2, barHeights[i] * h * 0.45);
                                const y = (h - bh) / 2;

                                if (played) {
                                    ctx.fillStyle = Qt.rgba(root.waveColor.r, root.waveColor.g, root.waveColor.b, 0.90);
                                } else {
                                    ctx.fillStyle = Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.25);
                                }

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
                            if (prog > 0 && prog < 1) {
                                ctx.fillStyle = Qt.rgba(root.controlColor.r, root.controlColor.g, root.controlColor.b, 0.95);
                                const phX = playheadX - 1;
                                ctx.fillRect(phX, 0, 2, h);
                            }
                        }
                    }

                    Rectangle {
                        id: progressTrack
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: progressBar.pbStyle === 1 ? 4 : 2
                        visible: progressBar.pbStyle !== 4
                        height: progressBar.pbStyle === 1 ? 1 : progressBar.pbStyle === 2 ? (pbArea.containsMouse ? 6 : 4) : progressBar.pbStyle === 3 ? (pbArea.containsMouse ? 8 : 6) : (pbArea.containsMouse ? 5 : 3)
                        radius: height / 2
                        color: progressBar.pbStyle === 1 ? Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.06) : Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
                        border.color: Qt.rgba(1, 1, 1, 0.10)
                        border.width: progressBar.pbStyle === 1 ? 0 : 1

                        Behavior on height {
                            NumberAnimation {
                                duration: 150
                            }
                        }

                        Item {
                            id: progressFillClip
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * progressBar.progress
                            clip: true
                            Behavior on width {
                                NumberAnimation {
                                    duration: 90
                                    easing.type: Easing.Linear
                                }
                            }

                            // Style 0,2,3 — gradient fill
                            Rectangle {
                                anchors.fill: parent
                                radius: progressTrack.radius
                                visible: progressBar.pbStyle !== 1
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
                                    shadowOpacity: progressBar.pbStyle === 2 ? (root.isPlaying ? 0.65 : 0.35) : (root.isPlaying ? 0.38 : 0.18)
                                    shadowBlur: progressBar.pbStyle === 2 ? 0.45 : 0.28
                                }
                            }

                            // Style 1 — flat solid fill (Ultra Minimal)
                            Rectangle {
                                anchors.fill: parent
                                radius: progressTrack.radius
                                visible: progressBar.pbStyle === 1
                                color: Qt.rgba(root.pgStartColor.r, root.pgStartColor.g, root.pgStartColor.b, 0.75)
                            }

                            Rectangle {
                                width: Math.max(18, progressTrack.width * 0.22)
                                height: parent.height
                                radius: parent.height / 2
                                x: (progressFillClip.width + width) * progressBar.sweep - width
                                opacity: (root.isPlaying && progressBar.pbStyle !== 1 && progressBar.pbStyle !== 3) ? 0.72 : 0.0
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
                            width: progressBar.pbStyle === 2 ? (pbArea.containsMouse ? 10 : 8) : (pbArea.containsMouse ? 8 : 6)
                            height: width
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(parent.width - width, parent.width * progressBar.progress - width / 2))
                            color: Qt.rgba(root.controlColor.r, root.controlColor.g, root.controlColor.b, root.isPlaying ? 0.95 : 0.68)
                            opacity: (progressBar.pbStyle !== 1 && progressBar.pbStyle !== 3 && progressBar.pbStyle !== 4 && progressBar.progress > 0) ? 1.0 : 0.0
                            Behavior on x {
                                NumberAnimation {
                                    duration: 90
                                    easing.type: Easing.Linear
                                }
                            }
                            layer.enabled: progressBar.pbStyle !== 1 && progressBar.pbStyle !== 3
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: root.pgStartColor
                                shadowOpacity: progressBar.pbStyle === 2 ? (root.isPlaying ? 0.75 : 0.42) : (root.isPlaying ? 0.55 : 0.22)
                                shadowBlur: progressBar.pbStyle === 2 ? 0.60 : 0.40
                            }

                            SequentialAnimation on scale {
                                running: root.isPlaying && progressBar.visible && (progressBar.pbStyle === 0 || progressBar.pbStyle === 2)
                                loops: Animation.Infinite
                                NumberAnimation {
                                    from: 0.92
                                    to: 1.18
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    from: 1.18
                                    to: 0.92
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        text: progressBar.elapsedText
                        color: root.textColor
                        opacity: 0.50
                        font.pixelSize: 8
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        text: progressBar.totalText
                        color: root.textColor
                        opacity: 0.50
                        font.pixelSize: 8
                    }

                    MouseArea {
                        id: pbArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: mouse => {
                            const p = mpris2Model.currentPlayer;
                            if (!p)
                                return;
                            const len = p.length || p.mprisLength || 0;
                            if (!len)
                                return;
                            const ratio = progressTrack.width > 0 ? progressBar.clamp((mouse.x - progressTrack.x) / progressTrack.width, 0, 1) : 0;
                            const newPos = ratio * len;
                            progressBar.displayedPosition = newPos;
                            progressBar.anchorPosition = newPos;
                            progressBar.anchorMs = Date.now();

                            // Robust seek implementation for different MPRIS layers
                            if (typeof p.position !== "undefined" && p.canSeek !== false) {
                                p.position = newPos;
                            } else if (typeof p.SetPosition === "function") {
                                p.SetPosition(newPos);
                            } else if (typeof p.setPosition === "function") {
                                p.setPosition(newPos);
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    text: root.track
                    color: root.textColor
                    font.bold: true
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    text: root.artist
                    color: root.textColor
                    opacity: 0.6
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }
            }
        }
    }

    Mpris.Mpris2Model {
        id: mpris2Model
    }
}
