import QtQuick
import QtTest
import "../package/contents/ui/layouts" as Layouts

TestCase {
    id: testCase
    name: "LyricsLayout"
    when: windowShown
    visible: true
    width: 420
    height: 360
    QtObject {
        id: view
        property var configuration: ({
                layoutMode: "lyrics",
                showMpris: true,
                titleSize: 14,
                reducedMotion: true
            })
        property var lyricLines: []
        property int lyricIndex: 5
        property string lyricStatus: "ready"
        property color textColor: "white"
        property string defaultFontFamily: Qt.application.font.family
    }
    Layouts.Lyrics {
        id: subject
        width: 380
        height: 320
        view: view
    }
    function init() {
        failOnWarning(/TypeError|ReferenceError|Unable|Binding loop/);
        view.configuration = {
            layoutMode: "lyrics",
            showMpris: true,
            reducedMotion: true
        };
        subject.following = true;
        subject.width = 380;
        subject.height = 320;
        view.lyricIndex = 5;
        view.lyricLines = Array.from({
            length: 20
        }, (_, i) => ({
                    time: i * 5,
                    text: "A line of lyrics with room to breathe " + i
                }));
        waitForRendering(subject);
    }
    function test_typographyAndHighlight() {
        view.lyricIndex = 0;
        view.configuration = Object.assign({}, view.configuration, {
            lyricsFontSize: 30,
            lyricsCurrentWeight: 700,
            lyricsItalic: true,
            lyricsLetterSpacing: 1.2,
            lyricsLineHeight: 1.5,
            lyricsAlign: "right",
            lyricsHighlight: "custom",
            lyricsHighlightColor: "#ff8800",
            lyricsTextStyle: "outline",
            lyricsTextStyleColor: "#000000",
            lyricsFutureOpacity: 0.3,
            lyricsLineSpacing: 24,
            lyricsPadding: 26
        });
        waitForRendering(subject);
        const first = findChild(subject, "lyricsVerse_0");
        verify(first !== null);
        compare(first.font.pixelSize, 30);
        compare(first.font.weight, 700);
        compare(first.font.italic, true);
        compare(first.horizontalAlignment, Text.AlignRight);
        compare(first.color, "#ff8800");
        compare(first.style, Text.Outline);
        compare(first.lineHeight, 1.5);
        compare(findChild(subject, "lyricsDocument").spacing, 24);
        compare(findChild(subject, "lyricsDocument").x, 26);
    }
    function test_followPreferenceAndPosition() {
        view.configuration = Object.assign({}, view.configuration, {
            lyricsFollow: false
        });
        waitForRendering(subject);
        wait(60);
        const document = findChild(subject, "lyricsDocument");
        compare(subject.following, false);
        const before = document.contentY;
        view.lyricIndex = 10;
        wait(40);
        compare(document.contentY, before, "Disabled following must not move the document");
        verify(!findChild(subject, "lyricsFollowButton").visible);
        view.configuration = Object.assign({}, view.configuration, {
            lyricsFollow: true,
            lyricsFollowPosition: "top"
        });
        tryCompare(subject, "following", true);
        waitForRendering(subject);
        subject.followCurrent();
        const top = document.contentY;
        view.configuration = Object.assign({}, view.configuration, {
            lyricsFollowPosition: "bottom"
        });
        tryVerify(() => document.contentY < top);
    }
    function test_followAndReadAhead() {
        const document = findChild(subject, "lyricsDocument");
        verify(document.contentY > 0);
        const before = document.contentY;
        view.lyricIndex = 10;
        tryVerify(() => document.contentY > before);
        mouseDrag(document, 150, 180, 0, -70, Qt.LeftButton, Qt.NoModifier, 200);
        tryCompare(subject, "following", false);
        document.cancelFlick();
        const scrolled = document.contentY;
        view.lyricIndex = 15;
        wait(30);
        compare(document.contentY, scrolled, "Playback must not interrupt manual reading");
        mouseClick(findChild(subject, "lyricsFollowButton"));
        compare(subject.following, true);
        verify(document.contentY > scrolled);
    }
    function test_wrappingAndEmptyState() {
        subject.width = 240;
        view.lyricIndex = 0;
        verify(waitForRendering(subject));
        const first = findChild(subject, "lyricsVerse_0");
        verify(first !== null);
        verify(first.implicitHeight > first.font.pixelSize * 2, "Long lines wrap instead of truncating");
        view.lyricLines = [];
        view.lyricStatus = "missing";
        const empty = findChild(subject, "lyricsEmptyState");
        verify(empty.visible);
        verify(empty.text.indexOf("No synced lyrics") >= 0);
    }
}
