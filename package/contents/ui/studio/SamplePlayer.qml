import QtQuick

// A sample track for the settings previews.
QtObject {
    property string track: "Slow Tide"
    property string artist: "Wren & Hollow"
    property string album: "Low Light"
    property string identity: "Music"
    property string artUrl: Qt.resolvedUrl("../../../icon.png").toString()
    property string desktopEntry: ""
    property real length: 238
    property real position: 91
    property real volume: 0.6
    property bool canSeek: false
    property bool shuffle: false
    property int loopState: 0
    property var metadata: ({
            "xesam:genre": ["Ambient"],
            "xesam:trackNumber": 4,
            "xesam:contentCreated": "2024"
        })
    function previous() {
    }
    function next() {
    }
    function togglePlaying() {
    }
}
