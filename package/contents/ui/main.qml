import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami
import "../code/Layouts.js" as LayoutSizes

PlasmoidItem {
    id: root
    readonly property bool shouldShow: !!mpris2Model.currentPlayer || plasmoid.configuration.alwaysVisible
    Layout.minimumWidth: shouldShow ? Math.min(160, LayoutSizes.size(plasmoid.configuration)[0]) : 0
    Layout.minimumHeight: shouldShow ? Math.min(64, LayoutSizes.size(plasmoid.configuration)[1]) : 0
    Layout.preferredWidth: shouldShow ? LayoutSizes.size(plasmoid.configuration)[0] : 0
    Layout.preferredHeight: shouldShow ? LayoutSizes.size(plasmoid.configuration)[1] : 0
    // Respect Plasma's system animation preference without writing over the
    // user's own reduced-motion setting.
    readonly property var effectiveConfiguration: {
        const source = plasmoid.configuration, copy = {};
        for (const key of source.keys())
            copy[key] = source[key];
        copy.reducedMotion = source.reducedMotion || Kirigami.Units.longDuration === 0;
        return copy;
    }
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    // In panels the pill (or, in vertical panels, the icon) opens the full card.
    preferredRepresentation: inPanel && plasmoid.configuration.autoPillInPanel ? compactRepresentation : fullRepresentation
    // The popup card: Classic with a card, glass unless a material is chosen,
    // at least 14 px radius, lifted shadow and no hover details.
    readonly property var popupConfiguration: {
        const source = root.effectiveConfiguration, copy = {};
        for (const key of Object.keys(source))
            copy[key] = source[key];
        return Object.assign(copy, {
            layoutMode: "classic",
            showBg: true,
            surfaceStyle: source.showBg ? source.surfaceStyle : "glass",
            bgRadius: Math.max(14, source.bgRadius),
            cardShadow: "lifted",
            hoverDetails: "off"
        });
    }
    // Desktop wallpaper is a separate scene item, safe to sample without
    // capturing our own text or other applets. Panel popups use another window.
    readonly property Item desktopWallpaper: {
        if (inPanel)
            return null;
        for (let item = root.parent; item; item = item.parent)
            if (item instanceof ContainmentItem)
                return item.wallpaper;
        return null;
    }
    Plasmoid.backgroundHints: "NoBackground"

    Mpris.Mpris2Model {
        id: mpris2Model
        // Row 0 is Plasma's automatic player choice; the others are players.
        property int playerRows: 0
        function refreshRows() {
            playerRows = Math.max(0, rowCount() - 1);
        }
        function cyclePlayer() {
            if (playerRows > 0)
                currentIndex = currentIndex % playerRows + 1;
        }
        onRowsInserted: refreshRows()
        onRowsRemoved: refreshRows()
        onModelReset: refreshRows()
        Component.onCompleted: refreshRows()
    }
    // Power source for the battery saver.
    Plasma5Support.DataSource {
        id: powerSource
        engine: "powermanagement"
        connectedSources: plasmoid.configuration.batterySaver ? ["AC Adapter"] : []
        readonly property bool onBattery: plasmoid.configuration.batterySaver && data["AC Adapter"] !== undefined && data["AC Adapter"]["Plugged in"] === false
    }
    Visualizer {
        id: vis
        batterySaverActive: powerSource.onBattery
        active: root.visible && root.shouldShow && root.width > 0 && root.height > 0
    }
    compactRepresentation: VisualizerView {
        id: pill
        presentation: Plasmoid.formFactor === PlasmaCore.Types.Vertical || plasmoid.configuration.layoutMode === "pillicon" ? "pillicon" : "pill"
        configuration: root.effectiveConfiguration
        visualizer: vis
        player: mpris2Model.currentPlayer
        isPlaying: player?.playbackStatus === Mpris.PlaybackStatus.Playing
        playerCount: mpris2Model.playerRows
        switchPlayer: mpris2Model.cyclePlayer
        onBattery: powerSource.onBattery
        accentColor: Kirigami.Theme.highlightColor
        systemTextColor: Kirigami.Theme.textColor
        defaultFontFamily: Kirigami.Theme.defaultFont.family
        Layout.minimumWidth: shouldShow ? implicitWidth : 0
        Layout.preferredWidth: shouldShow ? implicitWidth : 0
        Layout.maximumWidth: shouldShow ? implicitWidth : 0
        Layout.minimumHeight: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? implicitHeight : 0
        onPopupRequested: root.expanded = !root.expanded
        fallbackIcon: Component {
            Kirigami.Icon {
                source: pill.desktopEntry !== "" ? pill.desktopEntry : Qt.resolvedUrl("../../icon.png")
            }
        }
    }
    fullRepresentation: FittedFrame {
        id: fullFrame
        fitContents: LayoutSizes.mode(cardConfiguration) !== "lyrics"
        readonly property var cardConfiguration: root.inPanel ? root.popupConfiguration : root.effectiveConfiguration
        designSize: {
            const dimensions = LayoutSizes.size(cardConfiguration);
            return Qt.size(dimensions[0], dimensions[1]);
        }
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        VisualizerView {
            id: view
            backdropSource: root.desktopWallpaper
            renderScale: fullFrame.fitScale
            anchors.fill: parent
            configuration: root.inPanel ? root.popupConfiguration : root.effectiveConfiguration
            visualizer: vis
            player: mpris2Model.currentPlayer
            playerCount: mpris2Model.playerRows
            onBattery: powerSource.onBattery
            switchPlayer: mpris2Model.cyclePlayer
            isPlaying: player?.playbackStatus === Mpris.PlaybackStatus.Playing
            accentColor: Kirigami.Theme.highlightColor
            systemTextColor: Kirigami.Theme.textColor
            defaultFontFamily: Kirigami.Theme.defaultFont.family
            coverPalette: artColors
            Image {
                id: paletteImage
                source: (view.configuration.accentFromArt || view.configuration.vizColorMode === "cover") ? view.artUrl : ""
                sourceSize: Qt.size(64, 64)
                width: 64
                height: 64
                visible: false
                asynchronous: true
                onStatusChanged: {
                    if (status === Image.Ready)
                        artColors.update();
                }
            }
            Kirigami.ImageColors {
                id: artColors
                source: paletteImage.status === Image.Ready ? paletteImage : null
                fallbackDominant: view.baseWaveColor
                fallbackDominantContrasting: view.baseWaveColor
                fallbackHighlight: view.baseWaveColor
            }
            // Hover details (tooltip or drawer) in a borderless popup below the card.
            PlasmaCore.Dialog {
                id: detailsDialog
                // Named so the details' own `view` property does not shadow it.
                readonly property var cardView: view
                type: PlasmaCore.Dialog.Tooltip
                flags: Qt.WindowDoesNotAcceptFocus
                location: PlasmaCore.Types.Floating
                backgroundHints: PlasmaCore.Dialog.NoBackground
                visualParent: view
                visible: view.detailsVisible
                mainItem: TrackDetails {
                    width: Math.max(detailsDialog.cardView.width, 250)
                    height: implicitHeight
                    view: detailsDialog.cardView
                    mode: detailsDialog.cardView.detailsPopupMode
                }
            }
            fallbackIcon: Component {
                Kirigami.Icon {
                    source: view.desktopEntry !== "" ? view.desktopEntry : Qt.resolvedUrl("../../icon.png")
                }
            }
        }
    }
}
