import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    id: testCase
    name: "TransportDock"
    when: windowShown
    visible: true
    width: 180
    height: 50

    property var subject
    property int previousCalls: 0
    property int playCalls: 0
    property int pauseCalls: 0
    property int nextCalls: 0

    Component {
        id: dockComponent
        TransportDock {
            anchors.centerIn: parent
            configuration: ({
                    useSystemDockBg: true
                })
        }
    }

    Component {
        id: quickshellPlayer
        QtObject {
            property bool canControl: true
            property bool shuffleSupported: true
            property bool loopSupported: true
            property bool shuffle: false
            property int loopState: 0
        }
    }
    Component {
        id: plasmaPlayer
        QtObject {
            property bool canControl: true
            property int shuffle: 1
            property int loopStatus: 1
        }
    }

    function test_shuffleAndRepeat_data() {
        return [
            {
                tag: "quickshell",
                plasma: false
            },
            {
                tag: "plasma",
                plasma: true
            }
        ];
    }
    function test_shuffleAndRepeat(data) {
        const player = createTemporaryObject(data.plasma ? plasmaPlayer : quickshellPlayer, testCase);
        subject.player = player;
        subject.configuration = {
            useSystemDockBg: true,
            showShuffleRepeat: true
        };
        verify(waitForRendering(subject));
        clickControl("shuffleArea");
        compare(player.shuffle, data.plasma ? 2 : true);
        verify(subject.shuffleOn);
        clickControl("shuffleArea");
        compare(player.shuffle, data.plasma ? 1 : false);
        const loopKey = data.plasma ? "loopStatus" : "loopState";
        for (const value of (data.plasma ? [2, 3, 1] : [2, 1, 0])) {
            clickControl("repeatArea");
            compare(player[loopKey], value);
            compare(findChild(subject, "repeatAreaBadge").visible, value === (data.plasma ? 3 : 1));
        }
        player.canControl = false;
        clickControl("shuffleArea");
        clickControl("repeatArea");
        compare(player.shuffle, data.plasma ? 1 : false);
        compare(player[loopKey], data.plasma ? 1 : 0);
    }
    function test_unsupportedShuffleAndRepeat() {
        const player = createTemporaryObject(quickshellPlayer, testCase, {
            shuffleSupported: false,
            loopSupported: false
        });
        subject.player = player;
        subject.configuration = {
            useSystemDockBg: true,
            showShuffleRepeat: true
        };
        verify(waitForRendering(subject));
        verify(!subject.canShuffle && !subject.canLoop);
        clickControl("shuffleArea");
        clickControl("repeatArea");
        compare(player.shuffle, false);
        compare(player.loopState, 0);
        subject.player = createTemporaryObject(plasmaPlayer, testCase, {
            shuffle: 0,
            loopStatus: 0
        });
        verify(!subject.canShuffle && !subject.canLoop);
    }

    function init() {
        previousCalls = 0;
        playCalls = 0;
        pauseCalls = 0;
        nextCalls = 0;
        subject = createTemporaryObject(dockComponent, this);
        verify(subject !== null);
        waitForRendering(subject);
    }

    function clickControl(name) {
        const control = findChild(subject, name);
        verify(control !== null);
        mouseClick(control);
    }

    function test_playerApis_data() {
        return [
            {
                tag: "quickshell",
                previous: "previous",
                next: "next",
                toggle: "togglePlaying"
            },
            {
                tag: "lowercase-toggle",
                previous: "previous",
                next: "next",
                toggle: "playPause"
            },
            {
                tag: "uppercase-toggle",
                previous: "Previous",
                next: "Next",
                toggle: "PlayPause"
            },
            {
                tag: "lowercase-play-pause",
                previous: "previous",
                next: "next",
                play: "play",
                pause: "pause"
            },
            {
                tag: "uppercase-play-pause",
                previous: "Previous",
                next: "Next",
                play: "Play",
                pause: "Pause"
            }
        ];
    }

    function test_playerApis(data) {
        const player = {};
        player[data.previous] = () => testCase.previousCalls++;
        player[data.next] = () => testCase.nextCalls++;
        if (data.toggle) {
            player[data.toggle] = () => testCase.playCalls++;
        } else {
            player[data.play] = () => testCase.playCalls++;
            player[data.pause] = () => testCase.pauseCalls++;
        }
        subject.player = player;

        clickControl("prevArea");
        clickControl("nextArea");
        clickControl("playArea");
        subject.isPlaying = true;
        clickControl("playArea");

        compare(previousCalls, 1);
        compare(nextCalls, 1);
        compare(playCalls, data.toggle ? 2 : 1);
        compare(pauseCalls, data.toggle ? 0 : 1);
    }

    function test_disabledCapabilities() {
        subject.player = {
            canGoPrevious: false,
            canTogglePlaying: false,
            canGoNext: false,
            previous: () => testCase.previousCalls++,
            togglePlaying: () => testCase.playCalls++,
            next: () => testCase.nextCalls++
        };

        clickControl("prevArea");
        clickControl("playArea");
        clickControl("nextArea");

        compare(previousCalls, 0);
        compare(playCalls, 0);
        compare(nextCalls, 0);
    }

    function test_absentPlayerAndMethods() {
        for (const player of [null,
            {}
        ]) {
            subject.player = player;
            clickControl("prevArea");
            clickControl("nextArea");
            for (const playing of [false, true]) {
                subject.isPlaying = playing;
                clickControl("playArea");
            }
        }
        compare(previousCalls, 0);
        compare(playCalls, 0);
        compare(pauseCalls, 0);
        compare(nextCalls, 0);
    }
}
