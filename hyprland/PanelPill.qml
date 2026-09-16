pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../package/contents/ui" as Shared
import "../package/contents/code/Layouts.js" as LayoutSizes
import "Configuration.js" as Configuration

// Panel pill for Quickshell bars. In your bar:
//
//   import "/path/to/plasma-audio-visualizer/hyprland" as AudioVisualizer
//   AudioVisualizer.PanelPill { icon: false }
//
// It reads the same hyprland.json settings as the desktop widget (the pill*
// keys), shares the desktop widget's feeder, and opens the full card in a
// popup below the pill (pillClick "toggle" plays/pauses instead).
Item {
    id: root
    property bool icon: false
    // Extra overrides on top of hyprland.json.
    property var settings: ({})

    implicitWidth: pill.shouldShow ? pill.implicitWidth : 0
    implicitHeight: 30

    FileView {
        id: defaultsFile
        path: Qt.resolvedUrl("../package/contents/config/main.xml").toString().replace(/^file:\/\//, "")
        blockLoading: true
    }
    FileView {
        id: preferences
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/audio-wave-visualizer/hyprland.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var userSettings: {
        try {
            return Configuration.parsePreferences(preferences.text());
        } catch (error) {
            return ({});
        }
    }
    readonly property var configuration: Object.assign({}, Configuration.defaults(defaultsFile.text()), userSettings, settings)
    readonly property var popupConfiguration: Object.assign({}, configuration, {
        layoutMode: "classic",
        showBg: true,
        surfaceStyle: configuration.showBg ? configuration.surfaceStyle : "glass",
        bgRadius: Math.max(14, configuration.bgRadius),
        cardShadow: "lifted",
        hoverDetails: "off"
    })

    property var pinnedPlayer: null
    function cyclePlayer() {
        const players = Mpris.players.values;
        if (players.length === 0)
            return;
        root.pinnedPlayer = players[(players.indexOf(root.player) + 1) % players.length];
    }
    readonly property var player: {
        const players = Mpris.players.values;
        if (root.pinnedPlayer && players.indexOf(root.pinnedPlayer) !== -1)
            return root.pinnedPlayer;
        return players.find(p => p.isPlaying) || players[0] || null;
    }

    QtObject {
        id: audioConfig
        property int numBars: root.configuration.numBars
        property int framerate: Math.min(root.configuration.framerate, 15)
        property int sensitivity: root.configuration.sensitivity
        property real noiseReduction: root.configuration.noiseReduction
        property string inputMethod: root.configuration.inputMethod
    }
    // Audio is only read for a live EQ, the mini visualizer or the open popup.
    Shared.VisualizerCore {
        id: backend
        configuration: audioConfig
        runtimeDirectory: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/audio-wave-quickshell"
        active: !!root.player && (popup.visible || root.configuration.pillEq === "live" || root.configuration.pillEq === "wave")
        stopWhenInactive: true
        commandSourceComponent: Component {
            CommandProcess {
                runtimeDirectory: backend.runtimeDirectory
            }
        }
    }

    component Card: Shared.VisualizerView {
        id: card
        visualizer: backend
        player: root.player
        isPlaying: root.player?.isPlaying ?? false
        artist: root.player?.trackArtist ?? ""
        track: root.player?.trackTitle ?? ""
        playerArtUrl: root.player?.trackArtUrl ?? ""
        positionUnitsPerSecond: 1
        playerCount: Mpris.players.values.length
        switchPlayer: root.cyclePlayer
        accentColor: root.configuration.waveColor ?? "#b4befe"
        systemTextColor: root.configuration.textColor ?? "#cdd6f4"
        fallbackIcon: Component {
            Image {
                source: (card.desktopEntry !== "" ? Quickshell.iconPath(card.desktopEntry, true) : "") || Qt.resolvedUrl("../package/icon.png")
                fillMode: Image.PreserveAspectFit
            }
        }
    }

    Card {
        id: pill
        anchors.fill: parent
        presentation: root.icon || root.configuration.layoutMode === "pillicon" ? "pillicon" : "pill"
        configuration: root.configuration
        onPopupRequested: popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        readonly property var cardSize: LayoutSizes.size(root.popupConfiguration)
        anchor.item: pill
        anchor.rect.x: (pill.width - cardSize[0]) / 2
        anchor.rect.y: pill.height + 12
        implicitWidth: cardSize[0]
        implicitHeight: cardSize[1]
        color: "transparent"
        visible: false
        Card {
            anchors.fill: parent
            configuration: root.popupConfiguration
        }
    }
}
