import QtQuick
import ".."

// Progress bar wired to the view. The cover ring replaces it while a cover is
// shown; without one, style 10 falls back to style 0.
ProgressBar {
    id: root
    required property var view
    property bool artShown: false
    property bool hideTimes: false
    readonly property bool ringMode: (view.configuration.progressBarStyle ?? 0) === 10

    objectName: "progressBar"
    player: view.player
    isPlaying: view.isPlaying
    hasAudio: view.visualizer.hasAudio
    playbackActive: view.visualizer.plasmoidVisible
    style: ringMode && !artShown ? 0 : (view.configuration.progressBarStyle ?? 0)
    suppressed: ringMode && artShown
    showTimes: !hideTimes && (view.configuration.showTimes ?? true)
    timeFormat: view.configuration.timeFormat ?? "total"
    centerTimes: view.configuration.textAlign === "center"
    reducedMotion: view.configuration.reducedMotion ?? false
    track: view.track
    artist: view.artist
    textColor: view.textColor
    waveColor: view.waveColor
    controlColor: view.controlColor
    pgStartColor: view.pgStartColor
    pgEndColor: view.pgEndColor
    positionUnitsPerSecond: view.positionUnitsPerSecond
    visualFrameTime: view.visualFrameTime
}
