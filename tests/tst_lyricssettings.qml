import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../hyprland/Configuration.js" as Configuration

TestCase {
    name: "LyricsSettings"
    property var defaults
    property var pageComponent
    function initTestCase() {
        pageComponent = Qt.createComponent(Qt.resolvedUrl("../package/contents/ui/configStudio.qml"));
        compare(pageComponent.status, Component.Ready, pageComponent.errorString());
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        request.send();
        defaults = Configuration.defaults(request.responseText);
    }
    Component {
        id: pageRowComponent
        Kirigami.PageRow {
            width: 800
            height: 600
        }
    }
    function test_plasmaPageStack() {
        failOnWarning(/Setting initial properties failed|Value is null|Unable to assign|TypeError/);
        const stack = createTemporaryObject(pageRowComponent, this);
        verify(stack !== null);
        const properties = {
            title: "General"
        };
        for (const key of Object.keys(defaults))
            properties["cfg_" + key] = defaults[key];
        const page = stack.push(pageComponent, properties);
        verify(page !== null);
        compare(stack.currentItem, page);
        compare(page.title, "General");
        verify(page.parent !== null);
        stack.clear();
    }

    function test_plasmaRoundTrip() {
        const properties = {
            title: "General"
        };
        for (const key of Object.keys(defaults)) {
            properties["cfg_" + key] = defaults[key];
            properties["cfg_" + key + "Default"] = defaults[key];
        }
        const page = createTemporaryObject(pageComponent, this, properties);
        verify(page !== null);
        compare(page.title, "General");
        compare(page.padding, 0);
        compare(page.cfg_glassBlur, 0.85);
        page.assign({
            glassBlur: 0.32
        });
        compare(page.cfg_glassBlur, 0.32);
        compare(page.draft.glassBlur, 0.32);
        compare(page.defaults.glassBlur, 0.85);
        verify(page.actions !== undefined, "Settings must expose the Kirigami page interface");
        page.assign({
            lyricsFontSize: 34,
            lyricsInlineFontSize: 16,
            lyricsFollow: false,
            lyricsHighlightColor: "#ff8800",
            lyricsOffset: -1.5
        });
        compare(page.cfg_lyricsFontSize, 34);
        compare(page.cfg_lyricsInlineFontSize, 16);
        compare(page.cfg_lyricsFollow, false);
        compare(page.cfg_lyricsOffset, -1.5);
        compare(page.cfg_lyricsHighlightColor, "#ff8800");
        compare(page.cfg_lyricsFontSizeDefault, defaults.lyricsFontSize);
        for (const key of Object.keys(defaults).filter(k => k.startsWith("lyrics")))
            verify(page["cfg_" + key] !== undefined, "Plasma setting must persist: " + key);
    }
}
