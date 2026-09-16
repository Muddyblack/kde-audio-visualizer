pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Basic as Controls
import "layouts" as Layouts
import "../code/Layouts.js" as LayoutSizes

Item {
    id: root

    required property var configuration
    required property var visualizer
    property var player: null
    property bool isPlaying: false
    // Synthetic previews must not send sample metadata to lyrics services.
    property bool samplePlayback: false
    property Item backdropSource: null
    // Host scale is separate from logical layout size, for artwork sampling.
    property real renderScale: scale
    property color accentColor: "#b4befe"
    property color systemTextColor: "#cdd6f4"
    property string defaultFontFamily: Qt.application.font.family
    property Component fallbackIcon
    // Plasma supplies ImageColors; other hosts sample a tiny static cover.
    property var coverPalette: null
    // "card" follows layoutMode; hosts use "pill" or "pillicon" in panels.
    property string presentation: "card"
    // Pill click with pillClick "popup": the host opens the full card.
    signal popupRequested
    readonly property color baseWaveColor: configuration.useSystemAccent ? accentColor : configuration.customColor
    readonly property color coverColor1: coverPalette ? coverPalette.dominant : (coverSampler.item?.primary ?? baseWaveColor)
    readonly property color coverColor2: coverPalette ? coverPalette.dominantContrast : (coverSampler.item?.secondary ?? baseWaveColor)
    readonly property color coverAccent: coverPalette ? coverPalette.highlight : (coverSampler.item?.accent ?? baseWaveColor)
    Loader {
        id: coverSampler
        active: !root.coverPalette && root.shouldShow && root.artUrl !== "" && (root.configuration.accentFromArt || root.configuration.vizColorMode === "cover" || (root.configuration.showBg && (root.configuration.surfaceStyle === "atmosphere" || (root.configuration.surfaceStyle === "liquid" && root.configuration.glassTint === "cover"))))
        sourceComponent: CoverColors {
            source: root.artUrl
            fallback: root.baseWaveColor
        }
    }
    // Zero preserves Plasma's historical unit detection; Quickshell uses seconds.
    property real positionUnitsPerSecond: 0
    // Decorative motion shares audio frames; it must not start its own
    // display-refresh animation loop on every monitor.
    readonly property real visualFrameTime: visualizer.frameTimeMs ?? 0

    readonly property bool shouldShow: hasPlayer || configuration.alwaysVisible
    implicitWidth: (layoutLoader.item as Item)?.implicitWidth ?? 360
    implicitHeight: (layoutLoader.item as Item)?.implicitHeight ?? 104
    readonly property bool hasPlayer: !!player
    property string artist: player?.artist ?? ""
    property string track: player?.track ?? ""
    property string playerArtUrl: player?.artUrl ?? ""
    readonly property string desktopEntry: player?.desktopEntry ?? ""

    // Track information (Plasma PlayerContainer or Quickshell MprisPlayer).
    readonly property string album: player?.album ?? player?.trackAlbum ?? ""
    readonly property var metadata: player?.metadata ?? ({})
    readonly property string genre: {
        const value = metadata["xesam:genre"];
        return Array.isArray(value) ? value.join(", ") : String(value ?? "");
    }
    readonly property int trackNumber: Number(metadata["xesam:trackNumber"] ?? 0) || 0
    readonly property string year: String(metadata["xesam:contentCreated"] ?? "").slice(0, 4)
    readonly property string playerName: player?.identity ?? ""
    readonly property real volume: player && player.volume !== undefined ? player.volume : -1
    readonly property string lengthText: {
        const length = player ? (player.length || player.mprisLength || 0) : 0;
        if (length <= 0)
            return "";
        const units = positionUnitsPerSecond > 0 ? positionUnitsPerSecond : length >= 1000000 ? 1000000 : length >= 10000 ? 1000 : 1;
        const seconds = Math.floor(length / units);
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }
    // Hosts that know every running player set these for the player switcher.
    property int playerCount: hasPlayer ? 1 : 0
    property var switchPlayer: null
    readonly property bool lyricsEnabled: (configuration.showLyrics ?? false) || layoutMode === "lyrics"
    readonly property var lyricLines: samplePlayback && lyricsEnabled ? [
        {
            time: 0,
            text: "The light falls softly on the water"
        },
        {
            time: 8,
            text: "And the city fades to blue"
        },
        {
            time: 16,
            text: "Let the evening drift away"
        },
        {
            time: 24,
            text: "There is nothing left to hurry"
        },
        {
            time: 32,
            text: "Just a little room to stay"
        },
        {
            time: 40,
            text: "With the rhythm of the rain"
        }
    ] : lyricsLoader.item?.lines ?? []
    readonly property int lyricIndex: samplePlayback && lyricsEnabled ? 2 : lyricsLoader.item?.currentIndex ?? -1
    readonly property string lyricLine: lyricIndex >= 0 && lyricIndex < lyricLines.length ? lyricLines[lyricIndex].text : ""
    readonly property string lyricStatus: !hasPlayer ? "idle" : trackUnknown || artist === "" ? "metadata" : samplePlayback ? "ready" : lyricsLoader.item?.status ?? "loading"

    readonly property string detailsMode: layoutMode === "lyrics" || !hasPlayer || trackUnknown ? "off" : (configuration.hoverDetails ?? "off")
    readonly property bool panelForm: layoutMode === "pill" || layoutMode === "pillicon"
    readonly property bool flipEnabled: detailsMode === "flip" && layoutMode !== "strip" && !panelForm
    property bool detailsOpen: false
    readonly property bool flipped: flipEnabled && detailsOpen
    onFlipEnabledChanged: {
        if (!flipEnabled)
            detailsOpen = false;
    }
    // Tooltip and drawer are shown by the host in a popup outside the card.
    readonly property bool detailsVisible: (detailsMode === "tooltip" || detailsMode === "drawer" || (detailsMode === "flip" && (layoutMode === "strip" || panelForm))) && cardHovered
    readonly property string detailsPopupMode: detailsMode === "drawer" ? "drawer" : "tooltip"
    // Solid cards are light: system text and controls switch to dark ink.
    readonly property bool lightCard: configuration.showBg && configuration.surfaceStyle === "solid" && !(configuration.showMpris && configuration.artBg && artUrl !== "") && (configuration.autoContrast ?? true)
    readonly property color textColor: configuration.useSystemText ? (lightCard ? "#1e241d" : systemTextColor) : configuration.customTextColor
    readonly property color waveColor: configuration.accentFromArt ? coverAccent : baseWaveColor
    readonly property color controlColor: configuration.useSystemControls ? (lightCard ? "#1e241d" : "#ffffff") : configuration.customControlColor
    readonly property color pgStartColor: configuration.useSystemControls ? accentColor : controlColor
    readonly property color pgEndColor: configuration.useSystemControls ? "#ffffff" : controlColor

    // Well-behaved sources (Spotify, a normal youtube.com tab, tagged local
    // files) publish xesam:title and never reach any of this. What follows is
    // only for the ones that publish nothing: a browser tab pointed straight at a
    // CDN link, mpv on a `yt-dlp -g` URL, a proxy that strips the page. Plasma
    // then falls back to the URL cut at its last slash, and since googlevideo
    // links carry an unencoded "mime=video/mp4" that reaches us as a 300-char
    // query fragment ("mp4&rqh=1&gir=yes&clen=…").
    readonly property string displayTrack: _prettifyTrack(track)
    readonly property bool trackUnknown: hasPlayer && displayTrack === ""
    readonly property string sourceHint: trackUnknown ? _sourceHint(track) : ""

    // A name worth putting on the card, or "" when there is none. Never invents
    // a title — an unusable value becomes the "no metadata" state instead.
    function _prettifyTrack(raw) {
        const s = (raw || "").trim();
        if (s === "")
            return "";

        const urlParts = s.match(/^[a-z][a-z0-9+.-]*:\/\/([^/?#]*)([^?#]*)/i);
        const isPath = !urlParts && s.startsWith("/");
        // Leftover key=value&key=value soup. Real titles don't look like this.
        const isDebris = s.indexOf("&") !== -1 && (s.match(/[a-z0-9_]+=[^&]*/gi) || []).length >= 3;
        if (!urlParts && !isPath && !isDebris)
            return s;
        if (isDebris && !urlParts)
            return "";

        let name = urlParts ? urlParts[2] : s.split("?")[0];
        try {
            name = decodeURIComponent(name);
        } catch (e) {
            // malformed %-escape: keep the raw form
        }
        name = (name.split("/").filter(part => part !== "").pop() || "").replace(/\.[a-z0-9]{1,5}$/i, "").replace(/[_+]+/g, " ").trim();
        // A filename carries information; a generic stream endpoint does not.
        return /^(videoplayback|playback|stream|index|master|manifest|playlist)$/i.test(name) ? "" : name;
    }

    // Shown under "No track metadata" so the card still says where the sound is
    // coming from.
    function _sourceHint(raw) {
        const s = (raw || "").trim();
        const host = (s.match(/^[a-z][a-z0-9+.-]*:\/\/([^/?#]*)/i) || ["", ""])[1].toLowerCase();
        // googlevideo params survive even when the host got chopped off
        if (host.endsWith("googlevideo.com") || /(^|&)(itag|clen|gir|lmt|fvip|ratebypass|sparams)=/i.test(s))
            return qsTr("Direct YouTube stream");
        if (host !== "")
            return host.replace(/^www\./, "");
        return qsTr("Player published no title");
    }

    property string artUrl: ""

    // When the album art is already shown big as the card background, the small
    // square thumbnail on the left is redundant — hide it so the controls dock
    // gets the room instead. Falls back to showing the thumb if there's no art
    // yet (so art-bg mode without loaded art doesn't look empty).
    readonly property bool artIsBackground: root.configuration.showBg && root.configuration.artBg && artUrl !== ""

    function _refreshArtUrl() {
        const p = root.player;
        if (!p || !root.configuration.showMpris) {
            artUrl = "";
            return;
        }
        const url = root.playerArtUrl;
        if (url !== "")
            artUrl = url;
    }

    // Artwork click opens a transient lightbox outside the card bounds.
    property bool zoomOpen: false
    Loader {
        active: root.zoomOpen
        sourceComponent: ArtworkLightbox {
            view: root
        }
    }
    readonly property bool cardHovered: cardHover.hovered

    // Behaviour (docs/redesign-plan.md §7.5).
    readonly property bool idleMessage: !hasPlayer && (configuration.idleText ?? false)
    readonly property bool pausedPlayer: hasPlayer && !isPlaying
    // Hosts report the power source; battery saver caps frames and drops glow.
    property bool onBattery: false
    readonly property bool batterySaving: onBattery && (configuration.batterySaver ?? false)
    readonly property bool lifted: layoutMode !== "lyrics" && (configuration.hoverLift ?? false) && cardHovered

    function togglePlayback() {
        const p = player;
        if (!p || p.canTogglePlaying === false)
            return;
        if (p.togglePlaying)
            p.togglePlaying();
        else if (p.playPause)
            p.playPause();
        else if (p.PlayPause)
            p.PlayPause();
    }
    function previousTrack() {
        const p = player;
        if (p && p.canGoPrevious !== false)
            (p.previous || p.Previous || function () {}).call(p);
    }
    function nextTrack() {
        const p = player;
        if (p && p.canGoNext !== false)
            (p.next || p.Next || function () {}).call(p);
    }
    function activatePill() {
        if ((configuration.pillClick ?? "popup") === "toggle")
            togglePlayback();
        else
            popupRequested();
    }

    // Scrolling adjusts the system's output volume (via pactl) rather than the
    // MPRIS player's own volume, which most players don't implement at all.
    property real systemVolume: -1
    property real requestedVolume: -1
    readonly property real displayedVolume: requestedVolume >= 0 ? requestedVolume : Math.max(0, systemVolume)
    onSystemVolumeChanged: {
        // pactl reports whole percent, so match the request within that grain.
        if (requestedVolume >= 0 && Math.abs(systemVolume - requestedVolume) < 0.006) {
            requestedVolume = -1;
            volumeRequestTimeout.stop();
        }
    }
    function resetVolumeGesture() {
        requestedVolume = -1;
        volumeRequestTimeout.stop();
        volumeHide.stop();
        volumeOsd.shown = false;
    }
    function queryVolume() {
        sysVolumeSource.connectSource("pactl get-sink-volume @DEFAULT_SINK@");
    }
    function commitVolume() {
        if (requestedVolume < 0)
            return;
        sysVolumeSource.connectSource("pactl set-sink-volume @DEFAULT_SINK@ " + Math.round(requestedVolume * 100) + "%; pactl get-sink-volume @DEFAULT_SINK@");
    }
    function scrollSystemVolume(angleDelta, pixelDelta) {
        if (!volumeWheel.enabled)
            return false;
        // A wheel notch is 120 angle units; touchpads can send pixels only.
        const step = pixelDelta !== 0 ? pixelDelta / 40 * 0.04 : angleDelta / 120 * 0.04;
        if (!Number.isFinite(step) || step === 0)
            return false;
        requestedVolume = Math.max(0, Math.min(1, displayedVolume + step));
        volumeRequestTimeout.restart();
        // Coalesce rapid wheel ticks into one shell call instead of one per notch.
        volumeCommitTimer.restart();
        volumeOsd.shown = true;
        volumeHide.restart();
        return true;
    }
    CommandSource {
        id: sysVolumeSource
        sourceComponent: root.visualizer?.commandSourceComponent
        onNewData: function (source, data) {
            disconnectSource(source);
            const match = /(\d+)%/.exec(data["stdout"] || "");
            if (match)
                root.systemVolume = Math.max(0, Math.min(1, Number(match[1]) / 100));
        }
    }
    Timer {
        id: volumeCommitTimer
        interval: 60
        onTriggered: root.commitVolume()
    }
    Timer {
        id: volumeRequestTimeout
        interval: 750
        onTriggered: root.requestedVolume = -1
    }
    WheelHandler {
        id: volumeWheel
        objectName: "volumeWheel"
        target: null
        enabled: root.visible && !root.zoomOpen && !root.flipped && root.layoutMode !== "lyrics" && (root.configuration.scrollVolume ?? false) && root.hasPlayer && !!root.visualizer?.commandSourceComponent
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onEnabledChanged: {
            root.resetVolumeGesture();
            if (enabled)
                root.queryVolume();
        }
        onWheel: event => {
            event.accepted = root.scrollSystemVolume(event.angleDelta.y, event.pixelDelta.y);
        }
    }
    Timer {
        id: volumeHide
        interval: 1100
        onTriggered: volumeOsd.shown = false
    }
    // Keep the feedback inside the host bounds so panels cannot clip it.
    Rectangle {
        id: volumeOsd
        objectName: "volumeOsd"
        property bool shown: false
        x: Math.max(0, root.width - width - 3)
        y: root.height * 0.08
        width: 6
        height: root.height * 0.84
        radius: 6
        color: Qt.rgba(0, 0, 0, 0x77 / 255)
        border.color: Qt.rgba(1, 1, 1, 0x26 / 255)
        border.width: 1
        clip: true
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 250
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: parent.height * root.displayedVolume
            color: root.waveColor
        }
    }

    HoverHandler {
        id: cardHover
    }

    Loader {
        id: lyricsLoader
        active: !root.samplePlayback && root.lyricsEnabled && root.hasPlayer && !root.trackUnknown
        sourceComponent: LyricsSource {
            player: root.player
            isPlaying: root.isPlaying
            track: root.displayTrack
            artist: root.artist
            album: root.album
            positionUnitsPerSecond: root.positionUnitsPerSecond
            timingOffset: root.configuration.lyricsOffset ?? 0
            visualFrameTime: root.visualFrameTime
        }
    }

    onPlayerChanged: {
        resetVolumeGesture();
        detailsOpen = false;
        zoomOpen = false;
        artUrl = "";
        _refreshArtUrl();
    }
    onPlayerArtUrlChanged: _refreshArtUrl()
    Component.onCompleted: _refreshArtUrl()

    readonly property bool showMpris: configuration.showMpris
    onShowMprisChanged: _refreshArtUrl()

    Item {
        id: front
        objectName: "playbackFace"
        enabled: !root.flipped && frontTurn.angle === 0
        anchors.fill: parent
        visible: root.shouldShow
        // No clip: text and control shadows may extend beyond the card.
        // The flip turns each face separately and swaps them halfway;
        // backface visibility is unreliable with effects and canvases.
        opacity: Math.abs(frontTurn.angle) < 90 ? 1 : 0
        transform: (root.flipEnabled ? [frontTurn] : []).concat((root.configuration.hoverLift ?? false) ? [liftScale, liftShift] : [])
        Scale {
            id: liftScale
            origin.x: front.width / 2
            origin.y: front.height / 2
            xScale: root.lifted ? 1.01 : 1
            yScale: xScale
            Behavior on xScale {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
        Translate {
            id: liftShift
            y: root.lifted ? -3 : 0
            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
        Rotation {
            id: frontTurn
            origin.x: front.width / 2
            origin.y: front.height / 2
            axis.x: 0
            axis.y: 1
            axis.z: 0
            angle: root.flipped ? -180 : 0
            Behavior on angle {
                NumberAnimation {
                    duration: (root.configuration.reducedMotion ?? false) ? 0 : 350
                    easing.type: Easing.InOutCubic
                }
            }
        }

        CardSurface {
            backdropSource: root.backdropSource
            anchors.fill: parent
            configuration: root.layoutMode === "lyrics" ? Object.assign({}, root.configuration, {
                artBg: false
            }) : root.configuration
            artUrl: root.artUrl
            hasPlayer: root.hasPlayer
            cardRadius: root.panelForm ? root.height / 2 : root.configuration.bgRadius
            accentColor: root.waveColor
            coverColor1: root.coverColor1
            coverColor2: root.coverColor2
            bass: root.visualizer.bass ?? 0
        }

        // Panel forms: hover tint without a card, and a click on the pill.
        Rectangle {
            anchors.fill: parent
            visible: root.panelForm && !root.configuration.showBg && root.cardHovered
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0x14 / 255)
        }
        MouseArea {
            objectName: "pillClickArea"
            anchors.fill: parent
            enabled: root.panelForm
            visible: enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activatePill()
        }

        Loader {
            id: layoutLoader
            objectName: "layoutLoader"
            anchors.fill: parent
            // Dim the content (not the card) while paused.
            opacity: (root.configuration.dimWhenPaused ?? false) && root.pausedPlayer ? 0.55 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                }
            }
            sourceComponent: ({
                    mirrored: mirroredLayout,
                    inline: inlineLayout,
                    hero: heroLayout,
                    stacked: stackedLayout,
                    poster: posterLayout,
                    strip: stripLayout,
                    orbit: orbitLayout,
                    lyrics: lyricsLayout,
                    pill: pillLayout,
                    pillicon: pillIconLayout
                })[root.layoutMode] ?? classicLayout
        }
    }

    Loader {
        anchors.fill: parent
        active: root.flipEnabled && root.shouldShow
        sourceComponent: Item {
            id: backFace
            enabled: root.flipped && backTurn.angle === 0
            objectName: "flipBack"
            opacity: Math.abs(backTurn.angle) < 90 ? 1 : 0
            transform: Rotation {
                id: backTurn
                origin.x: backFace.width / 2
                origin.y: backFace.height / 2
                axis.x: 0
                axis.y: 1
                axis.z: 0
                angle: root.flipped ? 0 : 180
                Behavior on angle {
                    NumberAnimation {
                        duration: (root.configuration.reducedMotion ?? false) ? 0 : 350
                        easing.type: Easing.InOutCubic
                    }
                }
            }
            CardMaterial {
                anchors.fill: parent
                material: root.configuration.showBg && ["liquid", "solid", "atmosphere"].indexOf(root.configuration.surfaceStyle) !== -1 ? root.configuration.surfaceStyle : "glass"
                radius: root.configuration.bgRadius
                cover1: root.coverColor1
                cover2: root.coverColor2
            }
            TrackDetails {
                anchors.fill: parent
                view: root
                mode: "back"
            }
        }
    }

    // This control stays outside both transformed faces. Hovering the card
    // must never hide playback controls or move the way back to them.
    Controls.ToolButton {
        objectName: "flipDetailsButton"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        width: 22
        height: 22
        visible: root.flipEnabled && root.shouldShow && !root.zoomOpen
        focusPolicy: Qt.StrongFocus
        text: root.flipped ? "×" : "i"
        Accessible.name: root.flipped ? "Return to playback controls" : "Show track details"
        Controls.ToolTip.visible: hovered
        Controls.ToolTip.text: Accessible.name
        Controls.ToolTip.delay: 500
        onClicked: root.detailsOpen = !root.detailsOpen
        Keys.onEscapePressed: root.detailsOpen = false
        contentItem: Text {
            text: parent.text
            color: root.textColor
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: width / 2
            color: parent.hovered ? "#55303030" : "#33202020"
            border.color: "#33ffffff"
        }
    }

    readonly property string layoutMode: presentation !== "card" ? presentation : LayoutSizes.mode(configuration)

    Component {
        id: classicLayout
        Layouts.Classic {
            view: root
        }
    }
    Component {
        id: mirroredLayout
        Layouts.Classic {
            view: root
            mirrored: true
        }
    }
    Component {
        id: inlineLayout
        Layouts.Inline {
            view: root
        }
    }
    Component {
        id: heroLayout
        Layouts.Hero {
            view: root
        }
    }
    Component {
        id: stackedLayout
        Layouts.Stacked {
            view: root
        }
    }
    Component {
        id: posterLayout
        Layouts.Poster {
            view: root
        }
    }
    Component {
        id: pillLayout
        Layouts.Pill {
            view: root
        }
    }
    Component {
        id: pillIconLayout
        Layouts.PillIcon {
            view: root
        }
    }
    Component {
        id: lyricsLayout
        Layouts.Lyrics {
            view: root
        }
    }
    Component {
        id: orbitLayout
        Layouts.Orbit {
            view: root
        }
    }
    Component {
        id: stripLayout
        Layouts.Strip {
            view: root
        }
    }
}
