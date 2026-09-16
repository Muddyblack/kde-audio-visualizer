import QtQuick
import QtTest
import "../package/contents/ui"
import "../hyprland/Configuration.js" as Configuration
import "../package/contents/code/Layouts.js" as LayoutSizes

TestCase {
    id: testCase
    name: "VisualizerView"
    when: windowShown
    visible: true
    width: 400
    height: 140
    property var defaults
    property var subject
    property var player

    function initTestCase() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        request.send();
        defaults = Configuration.defaults(request.responseText);
        compare(defaults.numBars, 24);
        compare(defaults.artBgBlur, 0.22);
        compare(defaults.showMpris, true);
        compare(defaults.customColor, "#a855f7");
    }
    QtObject {
        id: backend
        property var bars: [300, 700, 900, 400]
        property real frameTimeMs: 0
        property int numBars: 4
        property real maxRange: 1000
        property bool hasAudio: true
        property bool backendFailed: false
        property bool plasmoidVisible: true
        property string backendCode: ""
        property string backendMessage: ""
        property string backendAction: ""
        property string backendHint: ""
    }
    Component {
        id: playerComponent
        QtObject {
            property string artist: "Artist"
            property string track: "Track"
            property string artUrl: ""
            property string desktopEntry: ""
            property real length: 180
            property real position: 60
            property bool canSeek: true
            property bool positionSupported: true
            property bool shuffle: false
            property int loopState: 0
            property string album: "Album"
            property string identity: "Spotify"
            property real volume: 0.5
            property int previousCalls: 0
            property int playCalls: 0
            property int nextCalls: 0
            function previous() {
                previousCalls++;
            }
            function togglePlaying() {
                playCalls++;
            }
            function next() {
                nextCalls++;
            }
        }
    }
    Component {
        id: viewComponent
        VisualizerView {
            width: 360
            height: 104
            visualizer: backend
            positionUnitsPerSecond: 1
            fallbackIcon: Component {
                Item {}
            }
        }
    }
    Component {
        id: detailsComponent
        TrackDetails {}
    }
    Component {
        id: lyricsComponent
        LyricsSource {}
    }
    function init() {
        testCase.width = 400;
        testCase.height = 140;
        player = createTemporaryObject(playerComponent, this);
        subject = createTemporaryObject(viewComponent, this, {
            configuration: Object.assign({}, defaults),
            player: player
        });
        verify(subject !== null);
        waitForRendering(subject);
    }
    function test_controlsAndSeeking() {
        mouseClick(findChild(subject, "prevArea"));
        mouseClick(findChild(subject, "playArea"));
        mouseClick(findChild(subject, "nextArea"));
        compare(player.previousCalls, 1);
        compare(player.playCalls, 1);
        compare(player.nextCalls, 1);
        const seek = findChild(subject, "pbArea");
        mouseClick(seek, seek.width / 2, seek.height / 2);
        verify(Math.abs(player.position - 90) < 2);
        player.canSeek = false;
        mouseClick(seek, seek.width / 4, seek.height / 2);
        verify(Math.abs(player.position - 90) < 2);
    }

    function test_progressUsesAudioFramesWithSlowFallback() {
        subject.isPlaying = true;
        const clock = findChild(subject, "positionClock");
        compare(clock.updateInterval, 1000);
        const before = clock.displayedPosition;
        wait(150);
        compare(clock.displayedPosition, before, "No independent 20 Hz progress ticker");
        backend.frameTimeMs = Date.now();
        verify(clock.displayedPosition > before, "A fresh waveform frame advances playback");
        subject.visible = false;
        const hidden = clock.displayedPosition;
        wait(50);
        backend.frameTimeMs = Date.now();
        compare(clock.displayedPosition, hidden, "Hidden views do not tick on audio frames");
    }
    function test_coveredViewPausesPlaybackClock() {
        subject.isPlaying = true;
        const clock = findChild(subject, "positionClock");
        verify(clock.active && clock.ticking);
        backend.plasmoidVisible = false;
        verify(!clock.active && !clock.ticking);
        const covered = clock.displayedPosition;
        wait(50);
        backend.frameTimeMs = Date.now();
        compare(clock.displayedPosition, covered, "Covered views ignore audio frames");
        backend.plasmoidVisible = true;
        verify(clock.active && clock.ticking);
        verify(clock.displayedPosition > covered, "Uncovering catches up playback");
    }
    function test_styles_data() {
        return [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(style => ({
                    tag: "progress-" + style,
                    style: style
                }));
    }
    function test_styles(data) {
        subject.configuration = Object.assign({}, defaults, {
            progressBarStyle: data.style,
            showBg: true
        });
        waitForRendering(subject);
        const clock = findChild(subject, "positionClock");
        compare(clock.elapsedText, "1:00");
        compare(clock.totalText, "3:00");
        verify(grabImage(subject).width > 0);
    }
    function test_timeLabelsAndFormat() {
        const bar = findChild(subject, "progressBar");
        compare(bar.implicitHeight, 18);
        compare(findChild(subject, "totalTimeLabel").text, "3:00");
        subject.configuration = Object.assign({}, defaults, {
            timeFormat: "remaining"
        });
        compare(findChild(subject, "totalTimeLabel").text, "-2:00");
        subject.configuration = Object.assign({}, defaults, {
            showTimes: false
        });
        compare(bar.implicitHeight, 9);
        verify(!findChild(subject, "elapsedTimeLabel").visible);
        verify(!findChild(subject, "totalTimeLabel").visible);
        // Time only keeps its labels even with time labels switched off.
        subject.configuration = Object.assign({}, defaults, {
            showTimes: false,
            progressBarStyle: 9
        });
        compare(bar.implicitHeight, 12);
        verify(findChild(subject, "timeOnlyRow").visible);
        compare(findChild(subject, "timeOnlyElapsed").text, "1:00");
        compare(findChild(subject, "timeOnlyTotal").text, "3:00");
    }

    function test_squiggleSettlesWhenPausedOrReduced() {
        subject.configuration = Object.assign({}, defaults, {
            progressBarStyle: 5
        });
        const seek = findChild(subject, "lineSeek");
        verify(seek.visible);
        compare(seek.amplitude, 0);
        subject.isPlaying = true;
        tryCompare(seek, "amplitude", 2.2);
        subject.configuration = Object.assign({}, defaults, {
            progressBarStyle: 5,
            reducedMotion: true
        });
        tryCompare(seek, "amplitude", 0);
        compare(seek.phase, 0, "A flat squiggle does not repaint on audio frames");
    }

    function test_coverRingSeeksAndPreservesCoverClick_data() {
        return [
            {
                tag: "rounded-seconds",
                shape: "rounded",
                length: 180
            },
            {
                tag: "circle-seconds",
                shape: "circle",
                length: 180
            },
            {
                tag: "rounded-microseconds",
                shape: "rounded",
                length: 180000000
            },
            {
                tag: "circle-microseconds",
                shape: "circle",
                length: 180000000
            }
        ];
    }
    function test_coverRingSeeksAndPreservesCoverClick(data) {
        subject.configuration = Object.assign({}, defaults, {
            progressBarStyle: 10,
            artShape: data.shape,
            artClick: "zoom"
        });
        player.length = data.length;
        player.artUrl = Qt.resolvedUrl("../package/icon.png").toString();
        tryCompare(findChild(subject, "classicArt"), "coverReady", true);
        verify(waitForRendering(subject));
        const ring = findChild(subject, "coverRing");
        for (const point of [[ring.width - 1, ring.height / 2, 0.25], [ring.width / 2, ring.height - 1, 0.5], [1, ring.height / 2, 0.75], [ring.width / 2, 1, 0]]) {
            mouseClick(ring, point[0], point[1]);
            fuzzyCompare(player.position, point[2] * data.length, 0.01);
            fuzzyCompare(ring.progress, point[2], 0.001);
            verify(!subject.zoomOpen, "Ring clicks must not activate the cover");
        }
        player.canSeek = false;
        mouseClick(ring, ring.width - 1, ring.height / 2);
        compare(player.position, 0);
        player.canSeek = true;
        player.positionSupported = false;
        mouseClick(ring, ring.width - 1, ring.height / 2);
        compare(player.position, 0);
        player.positionSupported = true;
        mouseClick(ring, ring.width / 2, ring.height / 2);
        verify(subject.zoomOpen, "Clicks through the ring centre retain the cover action");
        compare(player.position, 0);
    }

    function test_coverRingReplacesBar() {
        subject.configuration = Object.assign({}, defaults, {
            progressBarStyle: 10
        });
        const bar = findChild(subject, "progressBar");
        const ring = findChild(subject, "coverRing");
        verify(!bar.visible, "The ring shows progress instead of the bar");
        verify(ring.visible);
        fuzzyCompare(ring.progress, 1 / 3, 0.01);
        verify(ring.parent.width <= 66, "The cover shrinks to make room for the ring");
        subject.configuration = Object.assign({}, defaults, {
            progressBarStyle: 10,
            showArtThumb: false
        });
        verify(!ring.visible);
        verify(bar.visible);
        compare(bar.style, 0, "Without a cover the ring falls back to the default bar");
    }

    function test_layouts_data() {
        return [].concat(...["classic", "mirrored", "inline", "hero", "stacked", "poster", "strip", "orbit"].map(mode => [
                {
                    tag: mode + "-card",
                    mode: mode,
                    bg: true
                },
                {
                    tag: mode + "-bare",
                    mode: mode,
                    bg: false
                }
            ]));
    }
    function test_layouts(data) {
        subject.configuration = Object.assign({}, defaults, {
            layoutMode: data.mode,
            showBg: data.bg
        });
        const size = LayoutSizes.size(subject.configuration);
        compare(subject.implicitWidth, size[0]);
        compare(subject.implicitHeight, size[1]);
        subject.width = size[0];
        subject.height = size[1];
        waitForRendering(subject);
        // The HTML slim strip has no progress bar.
        const bar = findChild(subject, "progressBar");
        if (data.mode === "strip")
            compare(bar, null);
        else
            verify(bar !== null && bar.visible && bar.width > 60 && bar.x + bar.width <= subject.width + 1 && bar.y + bar.height <= subject.height + 1, "progress bar laid out");
        const play = findChild(subject, "playArea");
        verify(play !== null && play.visible && play.width > 0, "dock laid out");
        const wave = findChild(subject, data.mode === "poster" ? "posterTexture" : data.mode === "orbit" ? "orbitCanvas" : "canvasLoader");
        verify(wave !== null && wave.width > 60 && wave.height >= 20, "wave laid out");
    }
    function test_orbitSparksAreBoundedAndStop() {
        subject.configuration = Object.assign({}, defaults, {
            layoutMode: "orbit",
            orbitStyle: "sparks"
        });
        subject.width = 250;
        subject.height = 332;
        backend.bars = [1000, 1000, 1000, 1000];
        const orbit = findChild(subject, "orbitCanvas");
        verify(orbit !== null);
        for (let i = 0; i < 60; i++)
            backend.frameTimeMs += 33;
        verify(orbit.particles.length > 0, "Loud audio spawns sparks");
        verify(orbit.particles.length <= 32, "Sparks stay within the uniform budget");
        subject.configuration = Object.assign({}, defaults, {
            layoutMode: "orbit",
            orbitStyle: "sparks",
            reducedMotion: true
        });
        compare(orbit.particles.length, 0, "Reduced motion removes sparks");
        backend.bars = [300, 700, 900, 400];
    }
    function test_artworkShapes_data() {
        return [["sharp", w => 2], ["rounded", w => 10], ["squircle", w => w * 0.3], ["circle", w => w / 2], ["vinyl", w => w / 2], ["cd", w => w / 2]].map(row => ({
                    tag: row[0],
                    shape: row[0],
                    radius: row[1]
                }));
    }
    function test_artworkShapes(data) {
        subject.configuration = Object.assign({}, defaults, {
            artShape: data.shape,
            artFallback: "letters"
        });
        const art = findChild(subject, "classicArt");
        verify(art !== null && art.width > 0);
        fuzzyCompare(art.cornerRadius, data.radius(art.width), 0.01);
        verify(art.showFallbackArt, "Without a cover the initials placeholder is used");
        compare(art.initials("Track name here"), "TN");
    }
    function test_vinylSpinsOnAudioFramesOnly() {
        subject.configuration = Object.assign({}, defaults, {
            artShape: "vinyl"
        });
        player.artUrl = Qt.resolvedUrl("fixtures/cover-red-blue.ppm").toString();
        const art = findChild(subject, "classicArt");
        tryVerify(() => art.coverReady);
        subject.isPlaying = true;
        backend.frameTimeMs = 1000;
        backend.frameTimeMs = 1200;
        verify(art.spinAngle > 5, "Vinyl turns with audio frames");
        const angle = art.spinAngle;
        subject.isPlaying = false;
        backend.frameTimeMs = 1400;
        compare(art.spinAngle, angle, "A paused record stops");
        subject.isPlaying = true;
        art.visible = false;
        backend.frameTimeMs = 1600;
        backend.frameTimeMs = 1800;
        compare(art.spinAngle, angle, "Hidden artwork must not spin");
        art.visible = true;
        backend.frameTimeMs = 2000;
        compare(art.spinAngle, angle, "Resuming must not catch up hidden time");
        backend.frameTimeMs = 2200;
        verify(art.spinAngle > angle);
        for (const shape of ["rounded", "sharp", "squircle", "circle"]) {
            subject.configuration = Object.assign({}, defaults, {
                artShape: shape
            });
            compare(findChild(art, "artFace").rotation, 0, "Switching away from a disc restores an upright cover");
        }
        player.artUrl = "";
    }
    function test_dockStylesAndToggles() {
        subject.configuration = Object.assign({}, defaults, {
            showSkipButtons: false,
            showShuffleRepeat: true,
            dockStyle: "accent"
        });
        // Let the row lay out the newly shown buttons before clicking them.
        waitForRendering(subject);
        verify(!findChild(subject, "prevArea").parent.visible);
        verify(!findChild(subject, "nextArea").parent.visible);
        const shuffle = findChild(subject, "shuffleArea");
        const repeat = findChild(subject, "repeatArea");
        verify(shuffle.visible && repeat.visible);
        mouseClick(shuffle);
        compare(player.shuffle, true);
        mouseClick(repeat);
        compare(player.loopState, 2, "Repeat cycles to the playlist");
        subject.configuration = Object.assign({}, defaults, {
            dockStyle: "hover"
        });
        mouseMove(testCase, 395, 135);
        tryCompare(findChild(subject, "playArea").parent.parent.parent, "opacity", 0);
    }
    function test_coverClickZoom() {
        subject.configuration = Object.assign({}, defaults, {
            artClick: "zoom"
        });
        player.artUrl = Qt.resolvedUrl("fixtures/cover-red-blue.ppm").toString();
        const art = findChild(subject, "classicArt");
        tryVerify(() => art.coverReady);
        mouseClick(findChild(subject, "artClickArea"));
        verify(subject.zoomOpen);
        const zoom = findChild(subject, "artZoom");
        tryVerify(() => zoom.visible);
        verify(zoom.width > subject.width, "Lightbox is larger than the card");
        const closeArea = findChild(subject, "artZoomArea");
        waitForRendering(closeArea);
        mouseClick(closeArea, 8, 8);
        tryCompare(subject, "zoomOpen", false);
        player.artUrl = "";
    }
    function test_trackInfoLines() {
        let switches = 0;
        subject.playerCount = 3;
        subject.switchPlayer = () => switches++;
        subject.configuration = Object.assign({}, defaults, {
            showAlbum: true,
            showSource: true,
            showPlayerSwitch: true
        });
        waitForRendering(subject);
        compare(findChild(subject, "albumLine").text, "Album");
        verify(findChild(subject, "albumLine").visible);
        compare(findChild(subject, "sourceChip").text, "SPOTIFY");
        compare(findChild(subject, "playerSwitchLabel").text, "3 ▾");
        mouseClick(findChild(subject, "playerSwitchArea"));
        compare(switches, 1);
        verify(!findChild(subject, "lyricLine").visible, "No lyrics without the opt-in");
    }
    function test_detailRowsSkipMissingData() {
        subject.configuration = Object.assign({}, defaults, {
            detailFields: ["album", "genre", "format", "player", "length", "volume"]
        });
        const details = createTemporaryObject(detailsComponent, testCase, {
            view: subject
        });
        compare(details.rows.map(row => row[0]), ["Album", "Player", "Length", "Volume"]);
        compare(details.rows[2][1], "3:00");
    }
    function test_flipRequiresExplicitClickAndKeepsControlsReachable() {
        subject.configuration = Object.assign({}, defaults, {
            hoverDetails: "flip",
            showShuffleRepeat: true
        });
        mouseMove(subject, 20, 20);
        wait(400);
        verify(!subject.flipped, "Entering the card must not hide its controls");
        const shuffle = findChild(subject, "shuffleArea");
        mouseClick(shuffle);
        compare(player.shuffle, true);
        mouseClick(findChild(subject, "repeatArea"));
        compare(player.loopState, 2);
        mouseClick(findChild(subject, "playArea"));
        compare(player.playCalls, 1);
        const button = findChild(subject, "flipDetailsButton");
        const position = button.mapToItem(subject, 0, 0);
        mouseClick(button);
        verify(subject.flipped);
        const back = findChild(subject, "flipBack");
        tryCompare(back, "enabled", true);
        compare(button.mapToItem(subject, 0, 0), position, "Return button must not rotate");
        mouseMove(testCase, 395, 135);
        verify(subject.flipped, "Moving the pointer must not flip the card again");
        mouseClick(button);
        verify(!subject.flipped);
        tryCompare(findChild(subject, "playbackFace"), "enabled", true);
        mouseClick(findChild(subject, "playArea"));
        compare(player.playCalls, 2);
        mouseClick(button);
        verify(subject.flipped);
        keyClick(Qt.Key_Escape);
        verify(!subject.flipped);
    }
    function test_artTiltKeepsClickTargetsStable() {
        subject.configuration = Object.assign({}, defaults, {
            artTilt: true,
            artClick: "zoom",
            showShuffleRepeat: true
        });
        player.artUrl = Qt.resolvedUrl("../package/icon.png").toString();
        const art = findChild(subject, "classicArt");
        tryCompare(art, "coverReady", true);
        verify(waitForRendering(subject));
        const clickArea = findChild(art, "artClickArea");
        const shuffle = findChild(subject, "shuffleArea");
        const coverPosition = clickArea.mapToItem(subject, 0, 0);
        const buttonPosition = shuffle.mapToItem(subject, 0, 0);
        mouseMove(art, art.width / 2, art.height / 2);
        verify(!art.tilted, "Tilt waits briefly before starting");
        tryCompare(art, "tilted", true);
        wait(220);
        const face = findChild(art, "artFace");
        const topLeft = face.mapToItem(art, 0, 0), topRight = face.mapToItem(art, face.width, 0);
        const bottomLeft = face.mapToItem(art, 0, face.height), bottomRight = face.mapToItem(art, face.width, face.height);
        verify(Math.abs((topRight.x - topLeft.x) - (bottomRight.x - bottomLeft.x)) > 0.1, "Perspective makes the near and far edges different widths");
        compare(clickArea.mapToItem(subject, 0, 0), coverPosition);
        compare(shuffle.mapToItem(subject, 0, 0), buttonPosition);
        mouseClick(clickArea);
        verify(subject.zoomOpen, "The cover remains clickable during tilt");
        subject.zoomOpen = false;
        mouseClick(shuffle);
        compare(player.shuffle, true);
        tryCompare(art, "tilted", false);
        subject.configuration = Object.assign({}, subject.configuration, {
            reducedMotion: true
        });
        mouseMove(art, art.width / 2, art.height / 2);
        wait(200);
        verify(!art.tilted, "Reduced motion disables decorative tilt");
    }
    function test_marqueeScrollsOnAudioFrames() {
        player.track = "A very long track title that surely needs scrolling";
        subject.configuration = Object.assign({}, defaults, {
            marquee: true
        });
        const texts = findChild(subject, "layoutTexts");
        verify(texts.marquee);
        backend.frameTimeMs = 7000;
        verify(texts.marqueeOffset > 0);
        subject.configuration = Object.assign({}, defaults, {
            marquee: true,
            reducedMotion: true
        });
        compare(texts.marqueeOffset, 0);
    }
    function test_lyricsOnlyLayout() {
        testCase.width = 420;
        testCase.height = 360;
        subject.samplePlayback = true;
        subject.configuration = Object.assign({}, defaults, {
            layoutMode: "lyrics",
            showLyrics: false,
            scrollVolume: true
        });
        subject.width = 380;
        subject.height = 320;
        compare(subject.implicitWidth, 380);
        compare(subject.implicitHeight, 320);
        verify(waitForRendering(subject));
        const document = findChild(subject, "lyricsDocument");
        verify(document !== null);
        compare(document.count, 6);
        compare(document.currentIndex, 2);
        tryVerify(() => document.currentItem !== null);
        const current = document.currentItem;
        tryVerify(() => current.y >= document.contentY && current.y + current.height <= document.contentY + document.height);
        verify(subject.lyricLine.length > 0);
        compare(findChild(subject, "playArea"), null);
        compare(findChild(subject, "canvasLoader"), null);
        compare(findChild(subject, "classicArt"), null);
        compare(findChild(subject, "volumeWheel").enabled, false);
    }

    function test_lyricsParsing() {
        const lyrics = createTemporaryObject(lyricsComponent, testCase);
        const lines = lyrics.parse("[00:01.00]first\n[00:03.50][00:05]again\nno tag");
        compare(lines.map(line => line.time), [1, 3.5, 5]);
        compare(lines.map(line => line.text), ["first", "again", "again"]);
        compare(lyrics.requestKey, "", "No request without track metadata");
    }
    function test_idleMessageAndAmbientWave() {
        subject.player = null;
        subject.configuration = Object.assign({}, defaults, {
            alwaysVisible: true,
            idleText: true,
            idleAmbient: true
        });
        backend.hasAudio = false;
        const texts = findChild(subject, "layoutTexts");
        compare(texts.children[1].children[0].text, "Nothing playing");
        const wave = findChild(subject, "canvasLoader").parent;
        verify(wave.ambient && wave.hasAudio, "The ambient wave draws without audio");
        backend.hasAudio = true;
    }
    function test_pausedDimAndFade() {
        subject.isPlaying = false;
        subject.configuration = Object.assign({}, defaults, {
            dimWhenPaused: true,
            fadeVizWhenPaused: true
        });
        tryCompare(findChild(subject, "layoutLoader"), "opacity", 0.55);
        tryCompare(findChild(subject, "canvasLoader").parent, "opacity", 0.28);
        subject.isPlaying = true;
        tryCompare(findChild(subject, "layoutLoader"), "opacity", 1);
    }
    function test_batterySaverDropsGlow() {
        subject.configuration = Object.assign({}, defaults, {
            batterySaver: true,
            glowWave: true
        });
        const wave = findChild(subject, "canvasLoader").parent;
        verify(wave.glowWave);
        subject.onBattery = true;
        verify(!wave.glowWave, "No glow on battery");
    }
    function test_scrollChangesPlayerVolume() {
        subject.configuration = Object.assign({}, defaults, {
            scrollVolume: true
        });
        mouseWheel(subject, 100, 50, 0, 120);
        fuzzyCompare(player.volume, 0.54, 1e-6);
        verify(findChild(subject, "volumeOsd").shown);
    }
    function test_volumeHighResolutionAndBounds() {
        subject.configuration = Object.assign({}, defaults, {
            scrollVolume: true
        });
        verify(!subject.scrollPlayerVolume(0, 0));
        verify(subject.scrollPlayerVolume(0, 10));
        fuzzyCompare(player.volume, 0.51, 0.000001);
        mouseWheel(subject, 100, 50, 120, 0);
        fuzzyCompare(player.volume, 0.51, 0.000001, "Horizontal scroll must not change volume");
        mouseWheel(subject, 100, 50, 0, -120);
        fuzzyCompare(player.volume, 0.47, 0.000001);
        subject.scrollPlayerVolume(12000, 0);
        compare(player.volume, 1);
        subject.scrollPlayerVolume(-12000, 0);
        compare(player.volume, 0);
        const osd = findChild(subject, "volumeOsd");
        verify(osd.x >= 0 && osd.x + osd.width <= subject.width, "Feedback stays inside the widget");
        subject.configuration = Object.assign({}, defaults, {
            scrollVolume: false
        });
        verify(!subject.scrollPlayerVolume(120, 0));
        compare(player.volume, 0);
        verify(!osd.shown);
    }
    function test_volumeAccumulatesBeforePlayerAcknowledges() {
        const requests = [];
        const delayed = {
            track: "Track",
            artist: "Artist",
            length: 180,
            position: 60
        };
        Object.defineProperty(delayed, "volume", {
            get: function () {
                return 0.5;
            },
            set: function (value) {
                requests.push(value);
            }
        });
        subject.player = delayed;
        subject.configuration = Object.assign({}, defaults, {
            scrollVolume: true
        });
        mouseWheel(subject, 100, 50, 0, 120);
        mouseWheel(subject, 100, 50, 0, 120);
        mouseWheel(subject, 100, 50, 0, -120);
        compare(requests.length, 3);
        fuzzyCompare(requests[0], 0.54, 0.000001);
        fuzzyCompare(requests[1], 0.58, 0.000001);
        fuzzyCompare(requests[2], 0.54, 0.000001);
        fuzzyCompare(subject.displayedVolume, 0.54, 0.000001);
        subject.player = player;
        compare(subject.requestedVolume, -1, "A new player must not inherit pending volume");
        mouseWheel(subject, 100, 50, 0, 120);
        fuzzyCompare(player.volume, 0.54, 0.000001);
    }

    function test_panelPill() {
        subject.presentation = "pill";
        subject.configuration = Object.assign({}, defaults, {
            pillControls: "all",
            pillProgress: "underline",
            pillContent: "artist-title"
        });
        waitForRendering(subject);
        compare(subject.implicitHeight, 30);
        verify(subject.implicitWidth > 60 && subject.implicitWidth <= 300, "The pill follows its content up to the maximum width");
        compare(findChild(subject, "pillPrimary").text, "Artist");
        compare(findChild(subject, "pillSecondary").text, "Track");
        verify(findChild(subject, "pillUnderline").visible);
        mouseClick(findChild(subject, "pillPlayArea"));
        compare(player.playCalls, 1);
        mouseClick(findChild(subject, "pillNextArea"));
        compare(player.nextCalls, 1);
        let popups = 0;
        subject.popupRequested.connect(() => popups++);
        mouseClick(findChild(subject, "pillClickArea"), 8, 15);
        compare(popups, 1, "A click on the pill asks the host for the full card");
        subject.configuration = Object.assign({}, defaults, {
            pillClick: "toggle"
        });
        mouseClick(findChild(subject, "pillClickArea"), 8, 15);
        compare(player.playCalls, 2, "pillClick toggle plays/pauses");
        compare(popups, 1);
    }
    function test_panelIcon() {
        subject.presentation = "pillicon";
        subject.configuration = Object.assign({}, defaults, {
            pillEq: "live"
        });
        compare(subject.implicitWidth, 30);
        compare(subject.implicitHeight, 30);
        verify(findChild(subject, "pillIconArt") !== null);
        subject.configuration = Object.assign({}, defaults, {
            pillEq: "wave"
        });
        verify(findChild(subject, "pillOrbit").visible, "The mini orbit ring surrounds the cover");
    }
    function test_defaultCardLoadsNoMaterialLayers() {
        subject.configuration = Object.assign({}, defaults, {
            showBg: true
        });
        compare(findChild(subject, "cardMaterial"), null);
        compare(findChild(subject, "cardShadow"), null);
        compare(findChild(subject, "cardGrain"), null);
        compare(findChild(subject, "bassGlow"), null);
    }
    function test_cardMaterials_data() {
        return ["glass", "liquid", "solid", "atmosphere"].map(material => ({
                    tag: material,
                    material: material
                }));
    }
    function test_cardMaterials(data) {
        subject.configuration = Object.assign({}, defaults, {
            showBg: true,
            surfaceStyle: data.material,
            glassTint: "cover",
            cardShadow: "lifted",
            edgeHighlight: true,
            grain: true,
            bassPulse: true
        });
        tryVerify(() => findChild(subject, "cardMaterial") !== null);
        verify(findChild(subject, "cardShadow") !== null);
        verify(findChild(subject, "cardGrain") !== null);
        verify(findChild(subject, "bassGlow") !== null);
        waitForRendering(subject);
        compare(Qt.colorEqual(subject.textColor, "#1e241d"), data.material === "solid", "Solid cards use dark ink");
        compare(Qt.colorEqual(subject.controlColor, "#1e241d"), data.material === "solid");
    }
    function test_posterClockReplacesTimeLabels() {
        subject.configuration = Object.assign({}, defaults, {
            layoutMode: "poster",
            posterLines: 2
        });
        compare(subject.implicitHeight, 138);
        compare(findChild(subject, "posterClock").text, "1:00");
        verify(!findChild(subject, "totalTimeLabel").visible, "The large clock replaces the bar's labels");
        compare(findChild(subject, "posterMeta").text, "ARTIST");
        subject.configuration = Object.assign({}, defaults, {
            layoutMode: "poster",
            posterClock: false
        });
        verify(!findChild(subject, "posterClock").visible);
        verify(findChild(subject, "totalTimeLabel").visible);
    }

    function test_playerChangesClearOldArtwork() {
        player.artUrl = Qt.resolvedUrl("../package/icon.png").toString();
        compare(subject.artUrl, player.artUrl);
        subject.player = null;
        compare(subject.artUrl, "");
        verify(!subject.shouldShow);
        subject.configuration = Object.assign({}, defaults, {
            alwaysVisible: true
        });
        verify(subject.shouldShow);
    }

    function test_coverPaletteAndStyleReachTheVisibleWave() {
        subject.configuration = Object.assign({}, defaults, {
            visualizerType: 15,
            vizColorMode: "cover",
            accentFromArt: true,
            simpleRender: true,
            ribbonCurvature: 0.75,
            bloom: 1.25
        });
        subject.coverPalette = {
            dominant: Qt.rgba(1, 0, 0, 1),
            dominantContrast: Qt.rgba(0, 0, 1, 1),
            highlight: Qt.rgba(0, 1, 0, 1)
        };
        const loader = findChild(subject, "canvasLoader");
        tryVerify(() => loader.item !== null);
        compare(loader.item.visualizerType, 15);
        compare(loader.item.ribbonCurvature, 0.75);
        compare(loader.item.bloom, 1.25);
        verify(Qt.colorEqual(loader.item.waveColor, "lime"));
        verify(Qt.colorEqual(loader.item.coverColor1, "red"));
        verify(Qt.colorEqual(loader.item.coverColor2, "blue"));
        subject.coverPalette = null;
        player.artUrl = Qt.resolvedUrl("fixtures/cover-red-blue.ppm").toString();
        tryVerify(() => subject.coverColor1.r > 0.9 && subject.coverColor1.g < 0.1);
        tryVerify(() => subject.coverColor2.b > 0.9);
        subject.player = null;
        verify(Qt.colorEqual(loader.item.waveColor, subject.baseWaveColor), "No stale cover accent after player removal");
    }
}
