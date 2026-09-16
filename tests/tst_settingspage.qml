import QtQuick
import QtTest
import "../hyprland"
import "../hyprland/Configuration.js" as Configuration

TestCase {
    name: "HyprlandSettingsPage"
    when: windowShown
    visible: true
    width: 560
    height: 720
    SettingsPage {
        id: page
        anchors.fill: parent
        screenNames: ["DP-1", "HDMI-A-1"]
    }
    SignalSpy {
        id: applied
        target: page
        signalName: "apply"
    }
    SignalSpy {
        id: closed
        target: page
        signalName: "close"
    }
    SignalSpy {
        id: reset
        target: page
        signalName: "reset"
    }
    function initTestCase() {
        failOnWarning(/undefined|TypeError|ReferenceError|Binding loop/);
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        request.send();
        page.draft = Object.assign(Configuration.defaults(request.responseText), {
            widgetWidth: 360,
            widgetHeight: 104,
            verticalPosition: 0.6,
            monitor: "",
            desktopLayer: true,
            pauseWhenCovered: true,
            waveColor: "#b4befe",
            textColor: "#cdd6f4"
        });
    }
    function test_draftChangesRequireApplyAndButtonsWork() {
        page.setValue("monitor", "all");
        page.setValue("sensitivity", 175);
        page.setValue("detailFields", ["player", "album"]);
        page.setValue("layoutMode", "poster");
        compare(applied.count, 0);
        mouseClick(findChild(page, "applySettings"));
        compare(applied.count, 1);
        compare(applied.signalArguments[0][0].monitor, "all");
        compare(applied.signalArguments[0][0].sensitivity, 175);
        compare(applied.signalArguments[0][0].detailFields, ["player", "album"]);
        compare(applied.signalArguments[0][0].layoutMode, "poster");
        mouseClick(findChild(page, "resetSettings"));
        compare(reset.count, 1);
        mouseClick(findChild(page, "closeSettings"));
        compare(closed.count, 1);
    }
    function test_previewAccentIsIncludedWhenApplied() {
        applied.clear();
        page.setValue("useSystemAccent", true);
        page.setValue("accentFromArt", true);
        page.setValue("vizColorMode", "solid");
        verify(waitForRendering(page));
        const swatch = findChild(page, "previewAccent_f5b26b");
        verify(swatch !== null);
        mouseClick(swatch);
        compare(page.draft.customColor, "#f5b26b");
        compare(page.draft.useSystemAccent, false);
        compare(page.draft.accentFromArt, false);
        compare(applied.count, 0, "Choosing an accent edits the draft until Apply");
        compare(swatch.border.width, 2);
        const preview = findChild(page, "previewWidget");
        verify(Qt.colorEqual(preview.waveColor, "#f5b26b"));
        mouseClick(findChild(page, "applySettings"));
        compare(applied.count, 1);
        const saved = applied.signalArguments[0][0];
        compare(saved.customColor, "#f5b26b");
        compare(saved.useSystemAccent, false);
        compare(saved.accentFromArt, false);
        page.setValue("useSystemAccent", true);
        compare(swatch.border.width, 0, "The indicator follows the configured source");
    }

    function test_tabsSwitchSections() {
        compare(page.currentTabIndex, 0);
        const tab1 = findChild(page, "tabButton_1");
        verify(tab1 !== null);
        mouseClick(tab1);
        compare(page.currentTabIndex, 1);

        const tab3 = findChild(page, "tabButton_3");
        verify(tab3 !== null);
        mouseClick(tab3);
        compare(page.currentTabIndex, 3);

        const tab0 = findChild(page, "tabButton_0");
        verify(tab0 !== null);
        mouseClick(tab0);
        compare(page.currentTabIndex, 0);
    }
}
