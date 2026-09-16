pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../package/contents/ui" as Shared
import "Configuration.js" as Configuration
import "../package/contents/code/Layouts.js" as LayoutSizes

ShellRoot {
    id: root
    property int widgetWidth: 360
    property int widgetHeight: 104
    property real verticalPosition: 0.60
    property string monitor: ""
    property color waveColor: "#b4befe"
    property color textColor: "#cdd6f4"
    property int visualizerType: defaults.visualizerType
    property bool showMpris: defaults.showMpris
    property bool showBackground: defaults.showBg
    property bool desktopLayer: true
    // All keys use the Plasma configuration names (see contents/config/main.xml).
    property var settings: ({})
    property alias audio: audioDefaults
    // Preserve the original audio.* configuration API as defaults, so GUI
    // overrides still take precedence over values declared in shell.qml.
    QtObject {
        id: audioDefaults
        property int numBars: root.defaults.numBars
        // Updating desktop surfaces on several outputs keeps the compositor
        // busy. Keep the shared appearance with a lower standalone cadence;
        // explicit audio.*, GUI and declarative settings still take precedence.
        property int framerate: Math.min(root.defaults.framerate, 15)
        property int sensitivity: root.defaults.sensitivity
        property real noiseReduction: root.defaults.noiseReduction
        property string inputMethod: root.defaults.inputMethod
    }
    property bool settingsOpen: false
    property var userSettings: ({})
    property string settingsError: ""
    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/audio-wave-visualizer/hyprland.json"

    FileView {
        id: preferences
        path: root.configPath
        blockLoading: true
        printErrors: false
        atomicWrites: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.userSettings = Configuration.parsePreferences(text());
                root.settingsError = "";
            } catch (error) {
                root.settingsError = "Cannot read settings: " + error;
            }
        }
        onSaveFailed: root.settingsError = "Could not save settings to " + root.configPath
        onSaved: root.settingsError = ""
    }
    FileView {
        id: declarativeFile
        path: Quickshell.env("AUDIO_WAVE_DEFAULTS") || ""
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
    readonly property var declarativeSettings: {
        if (!declarativeFile.path)
            return ({});
        try {
            return Configuration.parsePreferences(declarativeFile.text());
        } catch (error) {
            console.warn("Invalid AUDIO_WAVE_DEFAULTS:", error);
            return ({});
        }
    }
    function configure() {
        settingsEditor.draft = Object.assign({}, configuration);
        settingsOpen = true;
    }
    function saveSettings(overrides) {
        userSettings = overrides;
        preferences.setText(JSON.stringify(overrides, null, 2) + "\n");
    }
    // Settings › Audio › Run diagnostics.
    Process {
        id: doctorProcess
        property var done: null
        command: ["bash", Qt.resolvedUrl("../package/contents/code/doctor.sh").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector {
            onStreamFinished: {
                if (doctorProcess.done)
                    doctorProcess.done(text);
                doctorProcess.done = null;
            }
        }
    }
    function runDiagnostics(done) {
        doctorProcess.done = done;
        doctorProcess.running = true;
    }
    IpcHandler {
        target: "settings"
        function open(): void {
            root.configure();
        }
    }

    FileView {
        id: defaultsFile
        path: Qt.resolvedUrl("../package/contents/config/main.xml").toString().replace(/^file:\/\//, "")
        blockLoading: true
    }
    readonly property var defaults: Configuration.defaults(defaultsFile.text())
    readonly property var baseline: Object.assign({}, defaults, {
        visualizerType: visualizerType,
        showMpris: showMpris,
        showBg: showBackground,
        numBars: audioDefaults.numBars,
        framerate: audioDefaults.framerate,
        sensitivity: audioDefaults.sensitivity,
        noiseReduction: audioDefaults.noiseReduction,
        inputMethod: audioDefaults.inputMethod,
        widgetWidth: widgetWidth,
        widgetHeight: widgetHeight,
        verticalPosition: verticalPosition,
        hAnchor: "center",
        monitor: monitor,
        waveColor: waveColor.toString(),
        textColor: textColor.toString(),
        desktopLayer: desktopLayer,
        pauseWhenCovered: true
    }, settings, declarativeSettings)
    readonly property var configuration: Object.assign({}, baseline, userSettings)
    readonly property bool shouldShow: !!player || configuration.alwaysVisible
    readonly property var selectedScreens: Configuration.screens(Quickshell.screens, configuration.monitor)
    readonly property var widgetRectangles: selectedScreens.map(screen => widgetGeometry(screen))

    // Desktop coordinates for coverage detection; panels use the same bounds
    // with the screen origin removed from their top margin.
    function widgetGeometry(screen) {
        // The default 360 × 104 follows the chosen layout; explicit sizes win.
        const layoutSize = LayoutSizes.size(configuration);
        const defaultSize = configuration.widgetWidth === 360 && configuration.widgetHeight === 104;
        const width = Math.min(defaultSize ? layoutSize[0] : configuration.widgetWidth, screen.width);
        const height = defaultSize ? layoutSize[1] : configuration.widgetHeight;
        return {
            name: screen.name,
            x: screen.x + (configuration.hAnchor === "left" ? 0 : configuration.hAnchor === "right" ? screen.width - width : (screen.width - width) / 2),
            y: screen.y + Math.max(0, Math.min(screen.height - height, screen.height * configuration.verticalPosition)),
            width: width,
            height: height
        };
    }
    Occlusion {
        id: occlusion
        enabled: root.configuration.pauseWhenCovered && root.configuration.desktopLayer && root.shouldShow
        rectangles: root.widgetRectangles
    }

    QtObject {
        id: audioConfig
        property int numBars: root.configuration.numBars
        property int framerate: root.configuration.framerate
        property int sensitivity: root.configuration.sensitivity
        property real noiseReduction: root.configuration.noiseReduction
        property string inputMethod: root.configuration.inputMethod
    }

    // The player switcher pins a player; otherwise follow the one playing.
    property var pinnedPlayer: null
    function cyclePlayer() {
        const players = Mpris.players.values;
        if (players.length === 0)
            return;
        const index = players.indexOf(root.player);
        root.pinnedPlayer = players[(index + 1) % players.length];
    }
    readonly property var player: {
        const players = Mpris.players.values;
        if (root.pinnedPlayer && players.indexOf(root.pinnedPlayer) !== -1)
            return root.pinnedPlayer;
        return players.find(p => p.isPlaying) || players[0] || null;
    }
    readonly property string runtimeDirectory: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/audio-wave-quickshell"

    readonly property bool onBattery: (configuration.batterySaver ?? false) && UPower.onBattery
    Shared.VisualizerCore {
        id: backend
        batterySaverActive: root.onBattery
        configuration: audioConfig
        runtimeDirectory: root.runtimeDirectory
        active: root.shouldShow && root.selectedScreens.some(screen => occlusion.coveredScreens.indexOf(screen.name) === -1)
        stopWhenInactive: true
        commandSourceComponent: Component {
            CommandProcess {
                runtimeDirectory: root.runtimeDirectory
            }
        }
    }

    Variants {
        model: root.selectedScreens
        PanelWindow {
            id: panel
            required property var modelData
            readonly property var widgetRectangle: root.widgetGeometry(modelData)
            screen: modelData
            implicitWidth: widgetRectangle.width
            implicitHeight: widgetRectangle.height
            // The window's screen getter changes while it maps/unmaps. Using
            // it here makes visibility depend on creation of the same window.
            visible: root.shouldShow && occlusion.coveredScreens.indexOf(modelData.name) === -1
            anchors.top: true
            margins.top: widgetRectangle.y - modelData.y
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: root.configuration.desktopLayer ? WlrLayer.Bottom : WlrLayer.Top
            WlrLayershell.namespace: "audio-wave-visualizer"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.RightButton
                onClicked: root.configure()
            }
            Shared.VisualizerView {
                id: view
                anchors.fill: parent
                configuration: root.configuration
                visualizer: backend
                player: root.player
                isPlaying: root.player?.isPlaying ?? false
                artist: root.player?.trackArtist ?? ""
                track: root.player?.trackTitle ?? ""
                playerArtUrl: root.player?.trackArtUrl ?? ""
                positionUnitsPerSecond: 1
                playerCount: Mpris.players.values.length
                switchPlayer: root.cyclePlayer
                onBattery: root.onBattery
                accentColor: root.configuration.waveColor
                systemTextColor: root.configuration.textColor
                fallbackIcon: Component {
                    Image {
                        source: (view.desktopEntry !== "" ? Quickshell.iconPath(view.desktopEntry, true) : "") || Qt.resolvedUrl("../package/icon.png")
                        fillMode: Image.PreserveAspectFit
                    }
                }
            }

            // Hover details (tooltip or drawer) below the card. The window
            // leaves 50 px around the details for their shadow.
            PopupWindow {
                id: detailsPopup
                // Named so the details' own `view` property does not shadow it.
                readonly property var cardView: view
                anchor.item: view
                anchor.rect.x: -50
                anchor.rect.y: (view.detailsPopupMode === "drawer" ? view.height - 14 : view.height + 10) - 50
                implicitWidth: Math.max(view.width, 250) + 100
                implicitHeight: hoverDetails.implicitHeight + 100
                color: "transparent"
                visible: view.detailsVisible && panel.visible
                Shared.TrackDetails {
                    id: hoverDetails
                    anchors.fill: parent
                    anchors.margins: 50
                    view: detailsPopup.cardView
                    mode: detailsPopup.cardView.detailsPopupMode
                }
            }
        }
    }

    FloatingWindow {
        visible: root.settingsOpen
        title: "Audio Visualizer Settings"
        implicitWidth: 1180
        implicitHeight: 800
        color: "#1e1e2e"
        onVisibleChanged: if (!visible)
            root.settingsOpen = false
        SettingsPage {
            id: settingsEditor
            anchors.fill: parent
            screenNames: Quickshell.screens.map(s => s.name)
            defaults: root.baseline
            diagnosticsRunner: root.runDiagnostics
            errorMessage: root.settingsError
            onApply: draft => {
                root.saveSettings(Configuration.overrides(root.baseline, draft));
            }
            onReset: {
                root.saveSettings({});
                draft = Object.assign({}, root.baseline);
            }
            onClose: root.settingsOpen = false
        }
    }
}
