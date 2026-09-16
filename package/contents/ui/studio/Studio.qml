import QtQuick
import QtQuick.Controls.Basic as Controls
import "Theme.js" as Theme
import "Schema.js" as Schema

// The shared settings studio for Plasma and Hyprland (docs/redesign-plan.md §9),
// styled after the HTML studio. Hosts own the draft: every change is emitted
// through `edited(next)` and the host assigns it back to `draft`.
Rectangle {
    // Children bind `studio: studioRoot`: their own `studio` property would
    // shadow an id of the same name.
    id: studioRoot
    property var draft: ({})
    property var defaults: ({})
    // "kde" or "hypr": platform notes and placement rows.
    property string env: "kde"
    property var screenNames: []
    // function(done(text)) running contents/code/doctor.sh, or null.
    property var diagnosticsRunner: null
    property color previewAccent: "#3daee9"
    property int currentTabIndex: 0
    property string query: ""
    onCurrentTabIndexChanged: body.contentY = 0
    property bool keepColors: false
    property string presetFilter: "all"
    signal edited(var draft)

    readonly property string currentTab: Schema.TABS[currentTabIndex].id
    // Nothing renders until the host has supplied a draft.
    readonly property bool ready: !!draft && draft.showMpris !== undefined
    // Previews animate only while the settings window is actually shown.
    readonly property bool onScreen: visible && !!Window.window && Window.window.visible
    readonly property color accent: draft.useSystemAccent === false ? draft.customColor : previewAccent
    readonly property var monitorOptions: [["", "First available display"], ["all", "Every monitor"]].concat(screenNames.map(name => [name, name]))
    readonly property bool wide: width >= 1000
    readonly property bool compact: !wide && height < 640
    readonly property int inset: compact ? 10 : 20
    readonly property bool anyResults: Schema.SECTIONS.some(section => section.rows.some(row => Schema.rowVisible(row, section, draft, env, query.trim().toLowerCase())) && (query.trim() !== "" || section.tab === currentTab))
    property alias backend: tileBackend
    property alias stillBackend: stillBackend
    property alias samplePlayer: samplePlayer

    function update(patch) {
        edited(Object.assign({}, draft, Schema.normalize(patch)));
    }
    function applyLook(settings) {
        const next = Schema.applyPreset(defaults, draft, settings, keepColors);
        next.userPresets = draft.userPresets ?? "";
        edited(next);
    }
    function userPresetList() {
        return Schema.parseUserPresets(draft.userPresets ?? "");
    }
    function addUserPreset(entry) {
        const list = userPresetList();
        list.push({
            id: "u" + Date.now(),
            name: entry.name,
            settings: entry.settings
        });
        update({
            userPresets: JSON.stringify(list)
        });
    }
    function saveUserPreset(name) {
        addUserPreset({
            name: name,
            settings: Schema.changedKeys(defaults, draft)
        });
    }
    function renameUserPreset(index, name) {
        const list = userPresetList();
        const trimmed = String(name).trim();
        if (!trimmed || !Number.isInteger(index) || index < 0 || index >= list.length)
            return false;
        list[index] = Object.assign({}, list[index], {
            name: trimmed
        });
        update({
            userPresets: JSON.stringify(list)
        });
        return true;
    }
    function removeUserPreset(index) {
        const list = userPresetList();
        list.splice(index, 1);
        update({
            userPresets: JSON.stringify(list)
        });
    }

    color: Theme.bg
    onQueryChanged: {
        body.contentY = 0;
        if (searchInput.text !== query)
            searchInput.text = query;
    }

    PreviewBackend {
        id: tileBackend
        running: studioRoot.onScreen
    }
    PreviewBackend {
        id: stillBackend
        running: false
    }
    SamplePlayer {
        id: samplePlayer
    }

    Shortcut {
        sequence: "/"
        enabled: !searchInput.activeFocus
        onActivated: searchInput.forceActiveFocus()
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: studioRoot.inset
        width: Math.max(0, parent.width - studioRoot.inset * 2)
        height: Math.max(0, parent.height - studioRoot.inset * 2)

        PreviewPane {
            id: pane
            compact: studioRoot.compact
            studio: studioRoot
            visible: studioRoot.ready
            x: studioRoot.wide ? panel.width + 20 : 0
            width: studioRoot.wide ? parent.width - panel.width - 20 : parent.width
            height: studioRoot.wide ? Math.min(parent.height, 420) : studioRoot.compact ? (optionsExpanded ? 250 : 112) : Math.min(260, parent.height * 0.38)
        }

        Rectangle {
            id: panel
            y: studioRoot.wide ? 0 : pane.height + (studioRoot.compact ? 8 : 14)
            width: studioRoot.wide ? Math.max(380, (parent.width - 20) * 0.52) : parent.width
            height: studioRoot.wide ? parent.height : Math.max(0, parent.height - y)
            radius: 18
            border.color: Theme.line2
            border.width: 1
            clip: true
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Theme.panelTop
                }
                GradientStop {
                    position: 1
                    color: Theme.panelBottom
                }
            }

            Row {
                id: header
                x: 18
                y: studioRoot.compact ? 8 : 16
                width: parent.width - 36
                spacing: 10
                Rectangle {
                    width: parent.width - surprise.width - 10
                    height: 36
                    radius: 10
                    color: Theme.sunk
                    border.color: searchInput.activeFocus ? "#66d1e5bd" : Theme.line2
                    border.width: 1
                    Canvas {
                        x: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.scale(14 / 24, 14 / 24);
                            ctx.strokeStyle = Theme.dim;
                            ctx.lineWidth = 2;
                            ctx.beginPath();
                            ctx.arc(11, 11, 7, 0, Math.PI * 2);
                            ctx.moveTo(20, 20);
                            ctx.lineTo(16.5, 16.5);
                            ctx.stroke();
                        }
                    }
                    TextInput {
                        id: searchInput
                        objectName: "studioSearch"
                        x: 33
                        width: parent.width - 33 - 34
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        clip: true
                        onTextEdited: studioRoot.query = text
                        Keys.onEscapePressed: studioRoot.query = ""
                    }
                    Text {
                        anchors.fill: searchInput
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text === ""
                        text: "Search settings…"
                        color: Theme.dim
                        font: searchInput.font
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 4
                        color: "transparent"
                        border.color: Theme.line2
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "/"
                            color: Theme.dim
                            font.pixelSize: 10
                        }
                    }
                }
                StudioButton {
                    id: surprise
                    text: "Surprise me"
                    onClicked: {
                        const next = Schema.surprise(studioRoot.defaults, studioRoot.draft);
                        next.userPresets = studioRoot.draft.userPresets ?? "";
                        studioRoot.edited(next);
                    }
                }
            }

            Item {
                id: tabs
                objectName: "studioTabs"
                x: 12
                y: header.y + header.height + (studioRoot.compact ? 4 : 12)
                width: parent.width - 24
                height: tabRow.implicitHeight
                Flow {
                    id: tabRow
                    width: parent.width
                    spacing: 2
                    Repeater {
                        id: tabRepeater
                        model: Schema.TABS
                        Item {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool selected: studioRoot.query.trim() === "" && studioRoot.currentTabIndex === index
                            objectName: "tabButton_" + index
                            width: tabContent.width + 16
                            height: 36
                            Row {
                                id: tabContent
                                x: 8
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: -1
                                spacing: 6
                                Canvas {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 15
                                    height: 15
                                    readonly property var signature: [tab.selected, tabArea.containsMouse]
                                    onSignatureChanged: requestPaint()
                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.reset();
                                        ctx.scale(15 / 24, 15 / 24);
                                        ctx.strokeStyle = tab.selected || tabArea.containsMouse ? Theme.text : Theme.muted;
                                        ctx.lineWidth = 1.7;
                                        ctx.lineCap = "round";
                                        ctx.lineJoin = "round";
                                        ctx.path = tab.modelData.icon;
                                        ctx.stroke();
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    color: tab.selected || tabArea.containsMouse ? Theme.text : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }
                            }
                            Rectangle {
                                x: 8
                                width: parent.width - 16
                                height: 2
                                radius: 1
                                anchors.bottom: parent.bottom
                                color: Theme.brand
                                visible: tab.selected
                            }
                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    studioRoot.currentTabIndex = tab.index;
                                    studioRoot.query = "";
                                    body.contentY = 0;
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                y: tabs.y + tabs.height
                width: parent.width
                height: 1
                color: Theme.line
            }

            Flickable {
                id: body
                objectName: "studioBody"
                y: tabs.y + tabs.height + 1
                width: parent.width
                height: parent.height - y
                contentHeight: sections.height + 28
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    policy: Controls.ScrollBar.AsNeeded
                }

                Column {
                    id: sections
                    x: 18
                    y: 6
                    width: body.width - 36
                    spacing: 18
                    Item {
                        width: 1
                        height: 0
                    }
                    Repeater {
                        model: studioRoot.ready ? Schema.SECTIONS.length : 0
                        StudioSection {
                            required property int index
                            width: sections.width
                            studio: studioRoot
                            sectionIndex: index
                        }
                    }
                    Text {
                        width: sections.width
                        visible: studioRoot.ready && !studioRoot.anyResults
                        topPadding: 30
                        horizontalAlignment: Text.AlignHCenter
                        text: "No settings match that search."
                        color: Theme.dim
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
