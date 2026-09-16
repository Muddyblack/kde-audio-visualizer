import QtQuick
import QtQuick.LocalStorage

// Opt-in synced lyrics from LRCLIB (https://lrclib.net). The owner creates this
// only while "showLyrics" is on, so no request is made otherwise. Results,
// including misses, are cached on disk with LocalStorage; misses are retried
// after a day. Network failures show nothing.
Item {
    id: root
    property var player: null
    property bool isPlaying: false
    property string track: ""
    property string artist: ""
    property string album: ""
    property real positionUnitsPerSecond: 0
    property real visualFrameTime: 0
    property real timingOffset: 0
    property var lines: []
    property string status: "idle"
    property var _request: null
    function cancelRequest() {
        if (!_request)
            return;
        const request = _request;
        _request = null;
        request.onreadystatechange = function () {};
        request.abort();
    }
    Component.onDestruction: cancelRequest()

    readonly property int durationSeconds: clock.lengthValue > 0 ? Math.round(clock.lengthValue / clock.unitsPerSecond) : 0
    readonly property string requestKey: track !== "" && artist !== "" ? [track, artist, album, durationSeconds].join("") : ""
    readonly property int currentIndex: {
        const seconds = clock.displayedPosition / clock.unitsPerSecond + Math.max(-10, Math.min(10, timingOffset));
        let index = -1;
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].time > seconds)
                break;
            index = i;
        }
        return index;
    }
    readonly property string currentLine: currentIndex >= 0 ? lines[currentIndex].text : ""

    PlaybackClock {
        id: clock
        objectName: "lyricsClock"
        unitScale: root.positionUnitsPerSecond
        updateInterval: 1000
        player: root.player
        playing: root.isPlaying
        track: root.track
        active: root.lines.length > 0
    }
    onVisualFrameTimeChanged: {
        if (clock.active && isPlaying)
            clock.tick();
    }

    // Metadata often arrives in several updates; request once it settles.
    Timer {
        id: settle
        interval: 400
        onTriggered: root.load()
    }
    onRequestKeyChanged: {
        cancelRequest();
        lines = [];
        status = requestKey === "" ? "idle" : "loading";
        settle.restart();
    }

    // "[mm:ss.xx]text", with any number of time tags per line.
    function parse(text) {
        const out = [];
        const tag = /\[(\d+):(\d+)(?:[.:](\d+))?\]/g;
        for (const raw of String(text || "").split("\n")) {
            const words = raw.replace(tag, "").trim();
            let match;
            tag.lastIndex = 0;
            while ((match = tag.exec(raw)) !== null)
                out.push({
                    time: Number(match[1]) * 60 + Number(match[2]) + (match[3] ? Number("0." + match[3]) : 0),
                    text: words
                });
        }
        return out.sort((a, b) => a.time - b.time);
    }

    function database() {
        return LocalStorage.openDatabaseSync("PlasmaAudioVisualizerLyrics", "1", "Synced lyrics cache", 2000000);
    }

    function load() {
        cancelRequest();
        const key = requestKey;
        if (key === "")
            return;
        let cached = null;
        try {
            database().transaction(tx => {
                tx.executeSql("CREATE TABLE IF NOT EXISTS lyrics(key TEXT PRIMARY KEY, synced TEXT, fetched INTEGER)");
                const result = tx.executeSql("SELECT synced, fetched FROM lyrics WHERE key = ?", [key]);
                if (result.rows.length)
                    cached = result.rows.item(0);
            });
        } catch (error) {
            cached = null;
        }
        if (cached && (cached.synced !== "" || Date.now() - cached.fetched < 86400000)) {
            lines = parse(cached.synced);
            status = lines.length ? "ready" : "missing";
            return;
        }
        const query = "track_name=" + encodeURIComponent(track) + "&artist_name=" + encodeURIComponent(artist) + (album !== "" ? "&album_name=" + encodeURIComponent(album) : "") + (durationSeconds > 0 ? "&duration=" + durationSeconds : "");
        status = "loading";
        const request = new XMLHttpRequest();
        _request = request;
        request.open("GET", "https://lrclib.net/api/get?" + query);
        request.setRequestHeader("Lrclib-Client", "plasma-audio-visualizer (https://github.com/Muddyblack/kde-audio-visualizer)");
        request.onreadystatechange = () => {
            if (!root || request.readyState !== XMLHttpRequest.DONE || request !== root._request || key !== root.requestKey)
                return;
            root._request = null;
            request.onreadystatechange = function () {};
            let synced = "";
            if (request.status === 200) {
                try {
                    synced = JSON.parse(request.responseText).syncedLyrics || "";
                } catch (error) {
                    synced = "";
                }
            } else if (request.status !== 404) {
                root.status = "error";
                return;
            }
            try {
                root.database().transaction(tx => tx.executeSql("INSERT OR REPLACE INTO lyrics VALUES (?, ?, ?)", [key, synced, Date.now()]));
            } catch (error) {}
            root.lines = root.parse(synced);
            root.status = root.lines.length ? "ready" : "missing";
        };
        request.send();
    }
}
