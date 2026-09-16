import QtQuick
import QtTest
import "../package/contents/ui" as Shared

TestCase {
    name: "LyricsLifecycle"
    Component {
        id: source
        Shared.LyricsSource {}
    }
    function request() {
        return {
            aborted: false,
            onreadystatechange: function () {},
            abort: function () {
                this.aborted = true;
            }
        };
    }
    Component {
        id: playerComponent
        QtObject {
            property real length: 180
            property real position: 0
        }
    }
    function test_currentVerseFollowsSeeking() {
        const player = createTemporaryObject(playerComponent, this);
        const lyrics = createTemporaryObject(source, this, {
            player: player,
            positionUnitsPerSecond: 1
        });
        lyrics.lines = lyrics.parse("[00:01]First line\n[00:05]Second line\n[00:10]Third line");
        compare(lyrics.currentIndex, -1);
        player.position = 6;
        compare(lyrics.currentIndex, 1);
        compare(lyrics.currentLine, "Second line");
        lyrics.timingOffset = 5;
        compare(lyrics.currentLine, "Third line", "Positive offset advances lyrics");
        lyrics.timingOffset = -5;
        compare(lyrics.currentLine, "First line", "Negative offset delays lyrics");
        lyrics.timingOffset = 0;
        player.position = 2;
        compare(lyrics.currentIndex, 0);
        player.position = 12;
        compare(lyrics.currentIndex, 2);
        lyrics.lines = [];
        compare(lyrics.currentIndex, -1);
        compare(lyrics.currentLine, "");
    }

    function test_cancelOnMetadataAndDestruction() {
        const lyrics = createTemporaryObject(source, this);
        const pending = request();
        lyrics._request = pending;
        lyrics.track = 'A new track';
        lyrics.artist = 'Artist';
        verify(pending.aborted);
        compare(lyrics._request, null);
        const last = request();
        lyrics._request = last;
        lyrics.destroy();
        wait(10);
        verify(last.aborted);
    }
}
