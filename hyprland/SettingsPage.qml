pragma ComponentBehavior: Bound
import QtQuick
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Theme.js" as Theme

// Hyprland settings window: the shared studio over a draft, with Reset, Close
// and Apply. Apply saves local overrides; Reset returns to configured defaults.
Rectangle {
    id: root
    color: Theme.bg
    property var draft: ({})
    property var defaults: ({})
    property var screenNames: []
    property string errorMessage: ""
    property alias currentTabIndex: studio.currentTabIndex
    // function(done(text)) running doctor.sh; supplied by the shell.
    property var diagnosticsRunner: null
    signal apply(var draft)
    signal reset
    signal close

    function setValue(key, value) {
        draft = Object.assign({}, draft, {
            [key]: value
        });
    }

    Studio.Studio {
        id: studio
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: footer.top
        env: "hypr"
        draft: root.draft
        defaults: Object.keys(root.defaults).length ? root.defaults : root.draft
        screenNames: root.screenNames
        diagnosticsRunner: root.diagnosticsRunner
        previewAccent: root.draft.waveColor ?? "#b4befe"
        onEdited: next => root.draft = next
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 60
        color: Theme.panel
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }
        Text {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - buttons.width - 60
            text: root.errorMessage !== "" ? root.errorMessage : "Apply saves local overrides. Reset returns to your configured defaults."
            color: root.errorMessage !== "" ? "#ff8a8a" : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Reset"
                areaName: "resetSettings"
                onClicked: root.reset()
            }
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                text: "Close"
                areaName: "closeSettings"
                onClicked: root.close()
            }
            Studio.StudioButton {
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                text: "Apply"
                areaName: "applySettings"
                onClicked: root.apply(root.draft)
            }
        }
    }
}
