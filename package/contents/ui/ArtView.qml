import QtQuick
import QtQuick.Effects

// Cover artwork. Without a `view` it draws the original rounded thumbnail; the
// layouts pass the view so the artwork options (docs/redesign-plan.md §7.2)
// apply. Vinyl/CD spin rides the audio frame clock rather than an animation.
Item {
    id: root
    property string artUrl: ""
    property string desktopEntry: ""
    property Component fallbackIcon
    property var view: null
    // Corner radius of the "rounded" shape (the panel pill uses 6 px).
    property real roundedRadius: 10

    readonly property var cfg: view ? view.configuration : ({})
    readonly property string shape: cfg.artShape ?? "rounded"
    readonly property string borderStyle: cfg.artBorder ?? "subtle"
    readonly property string fallback: cfg.artFallback ?? "icon"
    readonly property string clickAction: cfg.artClick ?? "none"
    readonly property string title: view ? view.displayTrack : ""
    readonly property bool isPlaying: view ? view.isPlaying : false
    readonly property bool reducedMotion: cfg.reducedMotion ?? false

    readonly property real sampleScale: Math.max(2, Screen.devicePixelRatio * (view ? (view.renderScale ?? 1) : 1))
    // The software cover is painted into a canvas that is then scaled back onto
    // the item, and that second resample eats detail: give it twice the samples.
    readonly property real rasterScale: Math.min(8, sampleScale * 2)
    // The canvas crops the cover itself, so it needs the artwork's real aspect
    // ratio, not the square-ish size the Image was asked to decode into.
    readonly property size artSize: Qt.size(Math.max(1, artImg.implicitWidth), Math.max(1, artImg.implicitHeight))
    readonly property bool software: GraphicsInfo.api === GraphicsInfo.Software
    readonly property bool coverReady: artImg.status === Image.Ready
    readonly property bool disc: shape === "vinyl" || shape === "cd"
    readonly property real cornerRadius: shape === "sharp" ? 2 : shape === "squircle" ? width * 0.3 : (shape === "circle" || disc) ? width / 2 : roundedRadius
    // Radius for the progress ring drawn 4 px outside (HTML `.artwrap .rg`).
    readonly property real ringRadius: (shape === "circle" || disc) ? (width + 8) / 2 : shape === "squircle" ? (width + 8) * 0.32 : 14
    readonly property bool showFallbackArt: !coverReady && fallback !== "icon" && title !== ""
    readonly property bool grayed: (cfg.artGrayPaused ?? false) && !!view && view.hasPlayer && !isPlaying
    readonly property bool spinning: visible && disc && coverReady && isPlaying && !reducedMotion
    readonly property bool tiltWanted: (cfg.artTilt ?? false) && !reducedMotion && artHover.hovered && !spinning && !artClickArea.pressed
    property bool tilted: false
    property real tiltProgress: tilted ? 1 : 0
    Behavior on tiltProgress {
        NumberAnimation {
            duration: root.reducedMotion ? 0 : 200
            easing.type: Easing.OutCubic
        }
    }
    onTiltWantedChanged: {
        if (tiltWanted)
            tiltDelay.restart();
        else {
            tiltDelay.stop();
            tilted = false;
        }
    }
    HoverHandler {
        id: artHover
    }
    Timer {
        id: tiltDelay
        interval: 160
        onTriggered: root.tilted = root.tiltWanted
    }

    function initials(text) {
        return text.split(/\s+/).filter(Boolean).slice(0, 2).map(word => word[0].toUpperCase()).join("");
    }
    function hashHue(text) {
        let hue = 0;
        for (let i = 0; i < text.length; i++)
            hue = (hue * 31 + text.charCodeAt(i)) % 360;
        return hue;
    }

    // Vinyl turns every 7 s and a CD every 3 s while playing.
    property real spinAngle: 0
    property real _lastSpinFrame: -1
    onSpinningChanged: _lastSpinFrame = -1
    Connections {
        target: root.view ?? null
        enabled: root.spinning && !!root.view
        ignoreUnknownSignals: true
        function onVisualFrameTimeChanged() {
            const now = root.view.visualFrameTime;
            if (!root.spinning) {
                root._lastSpinFrame = -1;
                return;
            }
            if (root._lastSpinFrame >= 0) {
                const elapsed = Math.max(0, Math.min(250, now - root._lastSpinFrame));
                root.spinAngle = (root.spinAngle + elapsed * 360 / (root.shape === "cd" ? 3000 : 7000)) % 360;
            }
            root._lastSpinFrame = now;
        }
    }

    // Glow tinted with the cover's dominant colour.
    Loader {
        anchors.fill: parent
        anchors.margins: -40
        active: (root.cfg.artGlow ?? false) && root.coverReady
        sourceComponent: CardGlow {
            margin: 40
            radius: root.cornerRadius
            layers: [
                {
                    y: 6,
                    blur: 24,
                    color: Qt.rgba(root.view.coverColor1.r, root.view.coverColor1.g, root.view.coverColor1.b, 0.7)
                }
            ]
        }
    }

    Item {
        id: face
        objectName: "artFace"
        anchors.fill: parent
        // A paused disc keeps its angle; ordinary covers are always upright.
        rotation: root.disc ? root.spinAngle : 0
        transform: [
            Matrix4x4 {
                matrix: {
                    const x = root.tiltProgress * 6 * Math.PI / 180;
                    const y = root.tiltProgress * -9 * Math.PI / 180;
                    const sx = Math.sin(x), cx = Math.cos(x), sy = Math.sin(y), cy = Math.cos(y);
                    const ox = face.width / 2, oy = face.height / 2;
                    const distance = Math.max(120, face.width * 2.4);
                    const wx = sy / distance, wy = -sx * cy / distance;
                    const a = cy + ox * wx, b = sx * sy + ox * wy;
                    const c = oy * wx, d = cx + oy * wy;
                    return Qt.matrix4x4(a, b, 0, ox - a * ox - b * oy, c, d, 0, oy - c * ox - d * oy, 0, 0, 1, 0, wx, wy, 0, 1 - wx * ox - wy * oy);
                }
            },
            Scale {
                origin.x: face.width / 2
                origin.y: face.height / 2
                xScale: root.tilted ? 1.02 : 1
                yScale: xScale
                Behavior on xScale {
                    NumberAnimation {
                        duration: root.reducedMotion ? 0 : 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
        ]

        Rectangle {
            anchors.fill: parent
            visible: !root.showFallbackArt && !(root.disc && root.coverReady)
            radius: root.cornerRadius
            color: Qt.rgba(1, 1, 1, 0.05)
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: root.borderStyle === "none" ? 0 : 1
        }

        // Placeholder without a cover: a title-hued gradient or initials.
        Canvas {
            anchors.fill: parent
            visible: root.showFallbackArt
            renderStrategy: Canvas.Cooperative
            readonly property var signature: [root.fallback, root.title, root.cornerRadius, width, height, visible]
            onSignatureChanged: {
                if (visible)
                    requestPaint();
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width, h = height;
                if (w <= 0 || h <= 0)
                    return;
                const r = Math.min(root.cornerRadius, w / 2, h / 2);
                const half = (w + h) / 4;
                const gradient = ctx.createLinearGradient(w / 2 - half, h / 2 - half, w / 2 + half, h / 2 + half);
                if (root.fallback === "gradient") {
                    const hue = root.hashHue(root.title);
                    gradient.addColorStop(0, Qt.hsla(hue / 360, 0.7, 0.6, 1));
                    gradient.addColorStop(1, Qt.hsla((hue + 60) % 360 / 360, 0.7, 0.35, 1));
                } else {
                    gradient.addColorStop(0, Qt.rgba(1, 1, 1, 0x1f / 255));
                    gradient.addColorStop(1, Qt.rgba(1, 1, 1, 0x08 / 255));
                }
                ctx.fillStyle = gradient;
                ctx.beginPath();
                ctx.roundedRect(0, 0, w, h, r, r);
                ctx.fill();
            }
        }
        Text {
            anchors.centerIn: parent
            visible: root.showFallbackArt && root.fallback === "letters"
            text: root.initials(root.title)
            color: root.view ? root.view.textColor : "#ffffff"
            opacity: 0.8
            font.pixelSize: Math.max(1, Math.round(root.width * 0.36))
            font.bold: true
            font.letterSpacing: -0.5
        }

        // Vinyl grooves or the iridescent CD face under the cover print.
        Canvas {
            id: discCanvas
            anchors.fill: parent
            visible: root.disc && root.coverReady
            renderStrategy: Canvas.Cooperative
            readonly property var signature: [root.shape, width, height, visible]
            onSignatureChanged: {
                if (visible)
                    requestPaint();
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = Math.min(width, height), R = w / 2;
                if (w <= 0)
                    return;
                ctx.save();
                ctx.beginPath();
                ctx.arc(R, R, R, 0, Math.PI * 2);
                ctx.clip();
                if (root.shape === "vinyl") {
                    ctx.fillStyle = "#1e1e1e";
                    ctx.fillRect(0, 0, w, w);
                    // repeating-radial-gradient(#101010 0 1.2px, #1e1e1e 1.2px 2.6px)
                    ctx.strokeStyle = "#101010";
                    ctx.lineWidth = 1.2;
                    for (let r = 0.6; r < R; r += 2.6) {
                        ctx.beginPath();
                        ctx.arc(R, R, r, 0, Math.PI * 2);
                        ctx.stroke();
                    }
                    const light = ctx.createRadialGradient(w * 0.3, w * 0.25, 0, w * 0.3, w * 0.25, w * 0.41);
                    light.addColorStop(0, Qt.rgba(1, 1, 1, 0x1f / 255));
                    light.addColorStop(1, Qt.rgba(1, 1, 1, 0));
                    ctx.fillStyle = light;
                    ctx.fillRect(0, 0, w, w);
                } else {
                    // conic-gradient(from 20deg, …); Qt's conical gradient runs
                    // counter-clockwise from +x, so the stops are reversed.
                    const colors = ["#d9e2e8", "#f6c6dd", "#bfe3f8", "#fff3b8", "#c9f0d4", "#e4d2fb", "#d9e2e8"];
                    const conic = ctx.createConicalGradient(R, R, (90 - 20) * Math.PI / 180);
                    for (let i = 0; i < colors.length; i++)
                        conic.addColorStop(1 - i / (colors.length - 1), colors[i]);
                    ctx.fillStyle = conic;
                    ctx.fillRect(0, 0, w, w);
                    const far = R * Math.SQRT2;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0xcc / 255);
                    ctx.lineWidth = far * 0.015;
                    ctx.beginPath();
                    ctx.arc(R, R, far * 0.1825, 0, Math.PI * 2);
                    ctx.stroke();
                }
                ctx.restore();
                ctx.strokeStyle = Qt.rgba(1, 1, 1, root.shape === "vinyl" ? 0x1a / 255 : 0x40 / 255);
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.arc(R, R, R - 0.5, 0, Math.PI * 2);
                ctx.stroke();
            }
        }

        Loader {
            anchors.centerIn: parent
            sourceComponent: root.fallbackIcon
            visible: !root.showFallbackArt
            width: root.desktopEntry !== "" ? parent.width * 0.72 : parent.width * 0.45
            height: width
            opacity: root.desktopEntry !== "" ? 0.70 : 0.35
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }
        }

        // MultiEffect samples an Image's raw texture directly, bypassing its
        // fillMode — crop it into a clipped wrapper first so PreserveAspectCrop
        // actually applies to the item bounds instead of leaving gaps.
        Item {
            id: artImgCrop
            anchors.fill: parent
            clip: true
            visible: false

            Image {
                id: artImg
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                // Keep at least 2x samples for small covers and respect HiDPI screens.
                sourceSize: Qt.size(Math.min(2048, Math.ceil(width * root.sampleScale)), Math.min(2048, Math.ceil(height * root.sampleScale)))
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
            }
        }

        // Cover shape. Discs show the cover as a round label (vinyl, 38 %) or a
        // faint print (CD, 88 %), each masked by a circle of its own size.
        Rectangle {
            id: artMask
            anchors.fill: parent
            radius: root.cornerRadius
            visible: false
            layer.enabled: true
            layer.textureSize: Qt.size(Math.min(2048, Math.ceil(width * root.sampleScale)), Math.min(2048, Math.ceil(height * root.sampleScale)))
        }

        MultiEffect {
            anchors.fill: parent
            visible: !root.software && !root.disc
            source: artImgCrop
            maskEnabled: true
            maskSource: artMask
            saturation: root.grayed ? -1 : 0
            brightness: root.grayed ? -0.25 : 0
            opacity: (artImg.status === Image.Ready || artImg.status === Image.Loading) ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: root.software && !root.disc && root.coverReady
            sourceComponent: SoftwareCover {
                source: root.artUrl
                imageSize: root.artSize
                rasterScale: root.rasterScale
                radius: root.cornerRadius
                grayed: root.grayed
            }
        }

        Item {
            id: label
            anchors.centerIn: parent
            visible: root.disc && root.coverReady
            width: parent.width * (root.shape === "cd" ? 0.88 : 0.38)
            height: width
            opacity: root.shape === "cd" ? 0.35 : 1

            Item {
                id: labelImgCrop
                anchors.fill: parent
                clip: true
                visible: false

                Image {
                    id: labelImg
                    anchors.fill: parent
                    source: label.visible ? root.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(Math.min(2048, Math.ceil(width * root.sampleScale)), Math.min(2048, Math.ceil(height * root.sampleScale)))
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    cache: true
                }
            }
            Rectangle {
                id: labelMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
                layer.textureSize: Qt.size(Math.min(2048, Math.ceil(width * root.sampleScale)), Math.min(2048, Math.ceil(height * root.sampleScale)))
            }
            Loader {
                anchors.fill: parent
                active: root.software && root.coverReady
                sourceComponent: SoftwareCover {
                    source: root.artUrl
                    imageSize: root.artSize
                    rasterScale: root.rasterScale
                    radius: width / 2
                    grayed: root.grayed
                }
            }
            MultiEffect {
                anchors.fill: parent
                visible: !root.software
                source: labelImgCrop
                maskEnabled: true
                maskSource: labelMask
                saturation: root.grayed ? -1 : 0
                brightness: root.grayed ? -0.25 : 0
            }
        }

        // Spindle hole.
        Rectangle {
            visible: root.disc && root.coverReady
            anchors.centerIn: parent
            width: parent.width * 0.08
            height: width
            radius: width / 2
            color: "#0c0c0c"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0x30 / 255)
        }

        Rectangle {
            anchors.fill: parent
            visible: root.borderStyle === "accent" && !root.disc
            radius: root.cornerRadius
            color: "transparent"
            border.width: 1.5
            border.color: root.view ? root.view.waveColor : "transparent"
        }
    }

    // Reflection below (GPU scene graph only; MultiEffect masks need it).
    Loader {
        active: (root.cfg.artReflect ?? false) && root.coverReady && GraphicsInfo.api !== GraphicsInfo.Software
        y: root.height + 3
        width: root.width
        height: root.height
        sourceComponent: Item {
            ShaderEffectSource {
                id: reflectionSource
                anchors.fill: parent
                sourceItem: face
                visible: false
            }
            Rectangle {
                id: reflectionMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.textureSize: Qt.size(Math.min(2048, Math.ceil(width * root.sampleScale)), Math.min(2048, Math.ceil(height * root.sampleScale)))
                gradient: Gradient {
                    GradientStop {
                        position: 0.55
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1
                        color: Qt.rgba(1, 1, 1, 0.25)
                    }
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: reflectionSource
                maskEnabled: true
                maskSource: reflectionMask
                transform: Scale {
                    origin.y: reflectionSource.height / 2
                    yScale: -1
                }
            }
        }
    }

    MouseArea {
        id: artClickArea
        objectName: "artClickArea"
        anchors.fill: parent
        enabled: root.clickAction !== "none" && root.coverReady && !!root.view
        visible: enabled
        cursorShape: root.clickAction === "zoom" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.clickAction === "zoom") {
                root.view.zoomOpen = true;
                return;
            }
            const player = root.view.player;
            if (player && player.canRaise !== false)
                (player.raise || player.Raise || function () {}).call(player);
        }
    }
}
