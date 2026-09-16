import QtQuick
import ".."

WaveArea {
    required property var view
    configuration: view.configuration
    visualizer: view.visualizer
    waveColor: view.waveColor
    textColor: view.textColor
    defaultFontFamily: view.defaultFontFamily
    coverColor1: view.coverColor1
    coverColor2: view.coverColor2
    faded: (view.configuration.fadeVizWhenPaused ?? false) && view.pausedPlayer
    batterySaving: view.batterySaving
    ambient: (view.configuration.idleAmbient ?? false) && !view.hasPlayer && !(view.visualizer.hasAudio ?? false)
}
