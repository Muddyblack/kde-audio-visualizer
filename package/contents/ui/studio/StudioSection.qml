import QtQuick
import "Theme.js" as Theme
import "Schema.js" as Schema

// Section (HTML `.sec`): uppercase title, then a rounded card of rows.
Column {
    id: sectionRoot
    required property var studio
    required property int sectionIndex

    readonly property var sectionData: Schema.SECTIONS[sectionIndex]
    readonly property string query: studio.query.trim().toLowerCase()
    readonly property var visibleRows: sectionData.rows.map((row, i) => i).filter(i => Schema.rowVisible(sectionData.rows[i], sectionData, studio.draft, studio.env, query))
    readonly property bool shown: (query !== "" || sectionData.tab === studio.currentTab) && visibleRows.length > 0

    objectName: "section_" + sectionData.tab + "_" + sectionIndex
    visible: shown
    spacing: 8

    Text {
        text: sectionRoot.sectionData.title.toUpperCase()
        color: Theme.sectionTitle
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
    }
    Rectangle {
        width: sectionRoot.width
        height: rows.height + 4
        radius: 14
        color: Theme.card
        border.color: Theme.line
        border.width: 1

        Column {
            id: rows
            x: 14
            y: 2
            width: parent.width - 28
            Repeater {
                model: sectionRoot.shown ? sectionRoot.sectionData.rows.length : 0
                StudioRow {
                    required property int index
                    width: rows.width
                    studio: sectionRoot.studio
                    sectionIndex: sectionRoot.sectionIndex
                    rowIndex: index
                    first: sectionRoot.visibleRows[0] === index
                }
            }
        }
    }
}
