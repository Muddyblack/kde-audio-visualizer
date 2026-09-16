import QtQuick
import QtQuick.Effects

// Cached card layers remain separate from the animated foreground.
Item {
    id: root
    required property var configuration
    property Item backdropSource: null
    property string artUrl: ""
    property bool hasPlayer: false
    property color accentColor: "#ffffff"
    property color coverColor1: "#6c7086"
    property color coverColor2: "#45475a"
    property real bass: 0

    // A loaded cover background (the "Cover" material) wins over surfaceStyle.
    readonly property bool coverActive: configuration.showMpris && configuration.artBg && artUrl !== ""
    readonly property string material: ["glass", "liquid", "solid", "atmosphere"].indexOf(configuration.surfaceStyle) !== -1 && !coverActive ? configuration.surfaceStyle : ""
    // Layouts may override it: the panel pill is fully rounded.
    property real cardRadius: configuration.bgRadius
    readonly property var shadowLayers: configuration.cardShadow === "lifted" ? [
        {
            y: 24,
            blur: 60,
            color: Qt.rgba(0, 0, 0, 0x73 / 255)
        },
        {
            y: 6,
            blur: 16,
            color: Qt.rgba(0, 0, 0, 0x40 / 255)
        }
    ] : [
        {
            y: 10,
            blur: 30,
            color: Qt.rgba(0, 0, 0, 0x4d / 255)
        },
        {
            y: 2,
            blur: 6,
            color: Qt.rgba(0, 0, 0, 0x33 / 255)
        }
    ]

    // Card shadow: static, behind everything, only with a visible card.
    Loader {
        anchors.fill: parent
        anchors.margins: -90
        active: root.configuration.showBg && (root.configuration.cardShadow ?? "none") !== "none"
        sourceComponent: CardGlow {
            objectName: "cardShadow"
            margin: 90
            radius: root.cardRadius
            layers: root.shadowLayers
        }
    }

    Loader {
        anchors.fill: parent
        active: (root.configuration.glassBlur ?? 0.85) > 0 && root.configuration.showBg && !root.coverActive && (root.material === "glass" || root.material === "liquid") && !!root.backdropSource && GraphicsInfo.api !== GraphicsInfo.Software
        opacity: root.configuration.artBgTransparency
        sourceComponent: BackdropBlur {
            strength: root.configuration.glassBlur ?? 0.85
            sourceItem: root.backdropSource
            radius: root.cardRadius
        }
    }

    // ── Background card source (rendered offscreen, used by backgroundCardEffect) ──
    // Art image source — must be a sibling, not child of backgroundCard
    Item {
        id: bgArtSource
        objectName: "backgroundArtCrop"
        anchors.fill: parent
        clip: true
        visible: false
        // MultiEffect samples an Image's original texture directly. Capture a
        // clipped item instead so PreserveAspectCrop applies to the card bounds.
        Image {
            id: bgArtImg
            objectName: "backgroundArtImage"
            anchors.fill: parent
            source: (root.configuration.showMpris && root.configuration.artBg) ? root.artUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }
    }

    Rectangle {
        id: backgroundCard
        anchors.fill: parent
        visible: false
        radius: root.cardRadius
        color: "transparent"
        clip: true

        // Crisp art fill — light blur keeps the cover clearly recognizable
        // (premium "bold cover" look) while still softening hard detail so
        // the wave/text read on top. Brighter + saturated vs the old heavy
        // frosted treatment.
        MultiEffect {
            anchors.fill: parent
            objectName: "backgroundArtEffect"
            source: bgArtSource
            blurEnabled: true
            // User-controlled blur (0 = crisp cover, 1 = heavy frost).
            blur: root.configuration.artBgBlur
            blurMax: 48
            saturation: 0.85
            opacity: (root.configuration.artBg && bgArtImg.status === Image.Ready) ? 1.0 : 0.0
            Behavior on blur {
                NumberAnimation {
                    duration: 250
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 400
                }
            }
        }

        // Whether the album art is actually being used as the fill right now.
        property bool artMode: root.configuration.artBg && bgArtImg.status === Image.Ready

        // Solid-colour fill — ONLY when not in art mode (art mode has its
        // own image fill above). Kept as its own rectangle (no gradient on
        // it) so there's never a color↔gradient conflict on a single
        // Rectangle, which was painting the whole card black.
        //
        // While idle (no MPRIS player at all — nothing to show art or a
        // custom colour for) fall back to a soft glass tint instead of the
        // raw configured bgColor, which otherwise defaults to near-black
        // and reads as a dead solid box. This mirrors the dock's default
        // glass look and keeps the idle state looking clean rather than
        // just "off". Once a player appears, the user's configured
        // background (colour or art) takes over as before.
        Rectangle {
            anchors.fill: parent
            visible: !backgroundCard.artMode
            color: root.hasPlayer ? root.configuration.bgColor : Qt.rgba(1, 1, 1, 0.06)
        }

        // NOTE: the art-darkness scrim is intentionally NOT here. backgroundCard
        // is visible:false and used only as a texture source for
        // backgroundCardEffect, so changing a child's opacity inside it does
        // not re-trigger the MultiEffect's texture capture (blur works because
        // it's a live property on the effect pipeline; child opacity does not).
        // The scrim lives in the live scene on top of the effect instead —
        // see `artScrim` below.

        // Border on top
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: root.cardRadius
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
        }
    }

    MultiEffect {
        id: backgroundCardEffect
        anchors.fill: parent
        source: backgroundCard
        visible: root.configuration.showBg && root.material === ""

        // Round the whole composited card (art + tint + border) in one pass.
        maskEnabled: true
        maskSource: cardRoundMask

        // Background card transparency — art + blur fade together as one layer.
        // Wave, text and controls remain fully opaque on top.
        opacity: root.configuration.artBgTransparency
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    // Software sessions cannot run MultiEffect. Preserve the basic card and
    // cover crop; blur remains a GPU effect.
    Loader {
        anchors.fill: parent
        active: GraphicsInfo.api === GraphicsInfo.Software && root.configuration.showBg && root.material === ""
        opacity: root.configuration.artBgTransparency
        sourceComponent: Item {
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: root.coverActive ? "transparent" : root.hasPlayer ? root.configuration.bgColor : Qt.rgba(1, 1, 1, 0.06)
            }
            SoftwareCover {
                anchors.fill: parent
                source: root.coverActive ? root.artUrl : ""
                imageSize: bgArtImg.sourceSize
                // Same second resample as the cover: paint above display size.
                rasterScale: Math.max(2, Screen.devicePixelRatio) * 2
                radius: root.cardRadius
            }
            Rectangle {
                anchors.fill: parent
                radius: root.cardRadius
                color: "transparent"
                border.width: 1
                border.color: "#20ffffff"
            }
        }
    }

    // Rounded-rectangle alpha mask for backgroundCardEffect. Rendered to a
    // texture (layer.enabled) so the MultiEffect can sample it; never shown.
    Rectangle {
        id: cardRoundMask
        anchors.fill: parent
        radius: root.cardRadius
        color: "black"
        visible: false
        layer.enabled: true
    }

    // Art-darkness scrim — LIVE in the scene (not inside the captured
    // backgroundCard source), so its opacity reacts instantly to the slider.
    // A plain Rectangle's own rounded gradient fill stays inside its corners
    // (the earlier corner-leak only affected clipped CHILDREN), so radius +
    // antialiasing is enough here without a separate mask pass.
    Rectangle {
        id: artScrim
        anchors.fill: parent
        antialiasing: true
        radius: root.cardRadius
        visible: root.configuration.showBg && root.configuration.artBg && bgArtImg.status === Image.Ready
        // 0 = art fully visible · 1 = strongly dimmed for readability.
        // Also inherits the background transparency so it fades with the card.
        opacity: root.configuration.artBgDim * root.configuration.artBgTransparency
        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: Qt.rgba(0, 0, 0, 0.72)
            }
            GradientStop {
                position: 0.5
                color: Qt.rgba(0, 0, 0, 0.85)
            }
            GradientStop {
                position: 1.0
                color: Qt.rgba(0, 0, 0, 0.98)
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: root.configuration.showBg && (root.material !== "" || (root.configuration.edgeHighlight ?? false))
        opacity: root.configuration.artBgTransparency
        sourceComponent: CardMaterial {
            material: root.material
            grain: root.configuration.grain ?? false
            radius: root.cardRadius
            glassTint: root.configuration.glassTint ?? "clear"
            specular: root.configuration.glassSpecular ?? true
            edgeHighlight: root.configuration.edgeHighlight ?? false
            cover1: root.coverColor1
            cover2: root.coverColor2
            // The HTML's dark base tone of the cover palette.
            cover3: Qt.rgba(root.coverColor1.r * 0.2 + root.coverColor2.r * 0.1, root.coverColor1.g * 0.2 + root.coverColor2.g * 0.1, root.coverColor1.b * 0.2 + root.coverColor2.b * 0.1, 1)
        }
    }

    Loader {
        anchors.fill: parent
        active: root.configuration.showBg && root.material === "" && (root.configuration.grain ?? false)
        opacity: root.configuration.artBgTransparency
        sourceComponent: CardGrain {
            radius: root.cardRadius
        }
    }

    // Bass pulse: the glow is painted once; audio frames change only opacity.
    Loader {
        anchors.fill: parent
        anchors.margins: -40
        active: root.configuration.bassPulse ?? false
        sourceComponent: CardGlow {
            objectName: "bassGlow"
            margin: 40
            radius: root.cardRadius
            layers: [
                {
                    y: 0,
                    blur: 22,
                    spread: 2,
                    color: root.accentColor
                }
            ]
            insetColor: root.accentColor
            opacity: Math.max(0, Math.min(1, root.bass)) * 0.7
        }
    }
}
