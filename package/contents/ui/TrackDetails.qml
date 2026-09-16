import QtQuick
import QtQuick.Layouts

// Track details (HTML `.hc` and the flipped card's `.back`): cover, title and
// artist, the configured detail rows and the lyric line.
// mode: tooltip · drawer · back
Item {
    id: root
    required property var view
    property string mode: "tooltip"
    readonly property bool back: mode === "back"
    readonly property bool drawer: mode === "drawer"

    function fieldList() {
        const fields = view.configuration.detailFields ?? "album,genre,format,player";
        return (Array.isArray(fields) ? fields : String(fields).split(",")).map(field => String(field).trim()).filter(Boolean);
    }
    // Rows without data are left out. Format needs the playing stream's node
    // (pw-dump) and is not available to the widget yet.
    readonly property var rows: fieldList().map(key => {
        switch (key) {
        case "album":
            return view.album !== "" ? [qsTr("Album"), view.album + (view.year !== "" ? " (" + view.year + ")" : "")] : null;
        case "track":
            return view.trackNumber > 0 ? [qsTr("Track"), String(view.trackNumber)] : null;
        case "genre":
            return view.genre !== "" ? [qsTr("Genre"), view.genre] : null;
        case "length":
            return view.lengthText !== "" ? [qsTr("Length"), view.lengthText] : null;
        case "player":
            return view.playerName !== "" ? [qsTr("Player"), view.playerName] : null;
        case "volume":
            return view.volume >= 0 ? [qsTr("Volume"), "", view.volume] : null;
        default:
            return null;
        }
    }).filter(Boolean)
    readonly property bool showLyric: (view.configuration.showLyrics ?? false) && view.lyricLine !== ""

    implicitWidth: back ? 0 : 250
    implicitHeight: back ? 0 : content.implicitHeight + (drawer ? 32 : 24)

    // Tooltip/drawer card: #16181acc glass, 14 px radius, deep shadow.
    Loader {
        anchors.fill: parent
        anchors.margins: -50
        active: !root.back
        sourceComponent: CardGlow {
            margin: 50
            radius: 14
            layers: [
                {
                    y: 18,
                    blur: 40,
                    color: Qt.rgba(0, 0, 0, 0x77 / 255)
                }
            ]
        }
    }
    Rectangle {
        anchors.fill: parent
        visible: !root.back
        color: Qt.rgba(0x16 / 255, 0x18 / 255, 0x1a / 255, 0xcc / 255)
        border.color: Qt.rgba(1, 1, 1, 0x21 / 255)
        border.width: 1
        topLeftRadius: root.drawer ? 0 : 14
        topRightRadius: root.drawer ? 0 : 14
        bottomLeftRadius: 14
        bottomRightRadius: 14
    }

    component DetailRow: RowLayout {
        id: row
        required property var modelData
        property int pixelSize: 10
        property real labelWidth: 48
        spacing: root.back ? 10 : 12
        Text {
            Layout.preferredWidth: row.labelWidth
            text: row.modelData[0]
            color: "#eef0ec"
            opacity: 0.5
            font.pixelSize: row.pixelSize
        }
        Text {
            Layout.fillWidth: true
            visible: row.modelData.length < 3
            text: row.modelData[1]
            color: "#eef0ec"
            horizontalAlignment: root.back ? Text.AlignLeft : Text.AlignRight
            elide: Text.ElideRight
            font.pixelSize: row.pixelSize
        }
        Item {
            Layout.fillWidth: true
            visible: row.modelData.length >= 3
            implicitHeight: 4
            Rectangle {
                anchors.right: root.back ? undefined : parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 60
                height: 4
                radius: 4
                color: Qt.rgba(1, 1, 1, 0x26 / 255)
                clip: true
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, row.modelData[2] ?? 0))
                    height: parent.height
                    color: root.view.waveColor
                }
            }
        }
    }

    // Tooltip and drawer layout.
    ColumnLayout {
        id: content
        visible: !root.back
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: root.drawer ? 20 : 12
        spacing: 9

        RowLayout {
            spacing: 10
            Layout.fillWidth: true
            ArtView {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                view: root.view
                artUrl: root.view.artUrl
                desktopEntry: root.view.desktopEntry
                fallbackIcon: root.view.fallbackIcon
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: root.view.displayTrack
                    color: "#eef0ec"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.view.artist
                    color: "#eef0ec"
                    opacity: 0.6
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
        ColumnLayout {
            objectName: "detailRows"
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: root.back ? [] : root.rows
                DetailRow {
                    Layout.fillWidth: true
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: -1
            visible: root.showLyric
            text: root.view.lyricLine
            color: root.view.waveColor
            opacity: 0.9
            font.italic: true
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    // Back of the flipped card: [cover 62][title + rows].
    RowLayout {
        visible: root.back
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 12

        ArtView {
            readonly property real edge: Math.max(0, Math.min(62, root.height - 22))
            Layout.preferredWidth: edge
            Layout.preferredHeight: edge
            Layout.alignment: Qt.AlignVCenter
            view: root.view
            artUrl: root.view.artUrl
            desktopEntry: root.view.desktopEntry
            fallbackIcon: root.view.fallbackIcon
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 2
                text: root.view.displayTrack
                color: root.view.textColor
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
            }
            Repeater {
                model: root.back ? root.rows : []
                DetailRow {
                    Layout.fillWidth: true
                    pixelSize: 9
                    labelWidth: 40
                }
            }
        }
    }
}
