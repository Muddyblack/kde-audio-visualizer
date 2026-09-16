import QtQuick
import QtTest
import "../package/contents/ui/studio" as Studio
import "../package/contents/ui/studio/Schema.js" as Schema
import "../hyprland/Configuration.js" as Configuration

TestCase {
    id: testCase
    name: "Studio"
    when: windowShown
    visible: true
    width: 1200
    height: 820
    property var defaults

    Studio.Studio {
        id: studio
        anchors.fill: parent
        env: "hypr"
        onEdited: next => draft = next
    }

    function tabIndex(id) {
        return Schema.TABS.findIndex(tab => tab.id === id);
    }

    function initTestCase() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        request.send();
        defaults = Object.assign(Configuration.defaults(request.responseText), {
            monitor: "",
            verticalPosition: 0.6,
            hAnchor: "center",
            widgetWidth: 360,
            widgetHeight: 104,
            desktopLayer: true,
            pauseWhenCovered: true
        });
    }
    function init() {
        failOnWarning(/undefined|TypeError|ReferenceError|Binding loop/);
        testCase.width = 1200;
        testCase.height = 820;
        studio.visible = true;
        studio.presetFilter = "all";
        studio.defaults = defaults;
        studio.draft = Object.assign({}, defaults);
        studio.query = "";
        studio.currentTabIndex = 0;
        studio.keepColors = false;
    }

    function test_presetsKeepPlacementAndOptionallyColours() {
        studio.draft = Object.assign({}, defaults, {
            verticalPosition: 0.3,
            customColor: "#123456",
            useSystemAccent: false,
            titleSize: 15
        });
        studio.applyLook(Schema.PRESETS.find(p => p.id === "glass").s);
        compare(studio.draft.surfaceStyle, "glass");
        compare(studio.draft.showBg, true);
        compare(studio.draft.verticalPosition, 0.3, "Placement is never part of a look");
        compare(studio.draft.titleSize, 11, "Other keys return to the defaults");
        compare(studio.draft.useSystemAccent, true);
        studio.keepColors = true;
        studio.draft = Object.assign({}, studio.draft, {
            useSystemAccent: false,
            customColor: "#123456"
        });
        studio.applyLook(Schema.PRESETS.find(p => p.id === "neon").s);
        compare(studio.draft.customColor, "#123456", "Keep my colours");
        verify(Schema.matchesPreset(defaults, Object.assign({}, defaults), Schema.PRESETS[0]), "Classic is the defaults");
    }

    function test_pickerValuesMapToStoredKeys() {
        const layout = Schema.SECTIONS.find(s => s.title === "Arrangement").rows[0];
        studio.update(Schema.rowPatch(layout, "compact"));
        compare(studio.draft.showMpris, false);
        compare(Schema.rowValue(layout, studio.draft), "compact");
        studio.update(Schema.rowPatch(layout, "hero"));
        compare(studio.draft.showMpris, true);
        compare(studio.draft.layoutMode, "hero");
        const cover = Schema.PRESETS.find(p => p.id === "cover");
        compare(cover.s.artBg, true);
        verify(cover.s.surfaceStyle === undefined);
        compare(Schema.PRESETS.find(p => p.id === "cd").s.detailFields, ["album", "track", "genre", "format"]);
    }

    function test_searchFindsRowsAcrossTabs() {
        studio.query = "bloom";
        waitForRendering(studio);
        const bloom = findChild(studio, "row_bloom");
        verify(bloom !== null && bloom.visible, "Rows from other tabs match");
        compare(findChild(studio, "row_numBars"), null, "Unmatched sections create no rows");
        verify(studio.anyResults);
        studio.query = "zzzz-nothing";
        verify(!studio.anyResults);
        studio.query = "";
    }
    function test_lyricsSettingsAndSavedLook() {
        studio.currentTabIndex = tabIndex("lyrics");
        verify(studio.currentTabIndex >= 0);
        waitForRendering(studio);
        verify(findChild(studio, "row_lyricsMode") !== null);
        const row = Schema.SECTIONS.find(section => section.tab === "lyrics").rows[0];
        studio.update(Schema.rowPatch(row, "full", studio.draft));
        compare(studio.draft.layoutMode, "lyrics");
        verify(studio.draft.showLyrics);
        waitForRendering(studio);
        verify(findChild(studio, "row_lyricsFontSize") !== null);
        studio.update({
            lyricsFontSize: 32,
            lyricsFollow: false,
            lyricsOffset: -1.5
        });
        studio.saveUserPreset("Reading");
        const settings = Schema.parseUserPresets(studio.draft.userPresets)[0].settings;
        compare(settings.lyricsFontSize, 32);
        compare(settings.lyricsFollow, false);
        compare(settings.lyricsOffset, -1.5);
        compare(Schema.rowPatch(row, "off", {
            layoutMode: "orbit"
        }).layoutMode, "orbit");
    }

    function test_tileAndSwitchUpdateDraft() {
        studio.currentTabIndex = tabIndex("viz");
        waitForRendering(studio);
        const tile = findChild(studio, "tile_visualizerType_7");
        verify(tile !== null);
        mouseClick(tile);
        compare(studio.draft.visualizerType, 7);
        mouseClick(findChild(studio, "tabButton_" + tabIndex("card")));
        compare(studio.currentTabIndex, tabIndex("card"));
        waitForRendering(studio);
        verify(findChild(studio, "row_showBg") !== null);
    }

    function test_userPresetsSaveAndImport() {
        studio.update({
            titleSize: 14,
            verticalPosition: 0.2
        });
        studio.saveUserPreset("Big text");
        const list = Schema.parseUserPresets(studio.draft.userPresets);
        compare(list.length, 1);
        compare(list[0].name, "Big text");
        compare(list[0].settings.titleSize, 14);
        verify(list[0].settings.verticalPosition === undefined, "Placement is not saved");
        const imported = Schema.importPreset('{"name":"Shared","settings":{"layoutMode":"compact","monitor":"DP-1","bogus":1}}', defaults);
        compare(imported.name, "Shared");
        compare(imported.settings.showMpris, false);
        verify(imported.settings.monitor === undefined && imported.settings.bogus === undefined);
        studio.addUserPreset(imported);
        compare(Schema.parseUserPresets(studio.draft.userPresets).length, 2);
        studio.removeUserPreset(0);
        compare(Schema.parseUserPresets(studio.draft.userPresets)[0].name, "Shared");
    }

    function test_glassBlurIsAdjustableAndSaved() {
        studio.currentTabIndex = tabIndex("card");
        studio.update({
            showBg: true,
            artBg: false,
            surfaceStyle: "glass"
        });
        verify(waitForRendering(studio));
        verify(findChild(studio, "row_glassBlur").visible);
        studio.update({
            glassBlur: 0.27
        });
        studio.saveUserPreset("Light frost");
        compare(studio.userPresetList()[0].settings.glassBlur, 0.27);
        studio.update({
            glassBlur: 0
        });
        compare(studio.draft.glassBlur, 0);
        studio.applyLook(studio.userPresetList()[0].settings);
        compare(studio.draft.glassBlur, 0.27);
    }

    function test_renameSavedPreset() {
        studio.saveUserPreset("Original");
        const before = studio.userPresetList()[0];
        studio.currentTabIndex = tabIndex("saved");
        verify(waitForRendering(studio));
        const tile = findChild(studio, "userPreset_0");
        mouseClick(findChild(tile, "renamePresetButton"));
        verify(tile.renaming);
        const input = findChild(tile, "renamePresetInput");
        compare(input.text, "Original");
        input.text = "  Evening glass  ";
        keyClick(Qt.Key_Return);
        const after = studio.userPresetList()[0];
        compare(after.name, "Evening glass");
        compare(after.id, before.id);
        compare(JSON.stringify(after.settings), JSON.stringify(before.settings));
        verify(!studio.renameUserPreset(0, "   "));
        verify(!studio.renameUserPreset(9, "Missing"));
        mouseClick(findChild(tile, "renamePresetButton"));
        input.text = "Discard this";
        keyClick(Qt.Key_Escape);
        compare(studio.userPresetList()[0].name, "Evening glass");
        verify(!tile.renaming);
    }

    function test_allTabsRender_data() {
        return Schema.TABS.map((tab, index) => ({
                    tag: tab.id,
                    index: index
                }));
    }

    function test_allTabsRender(data) {
        studio.currentTabIndex = data.index;
        verify(waitForRendering(studio));
        verify(studio.anyResults);
    }

    function test_shuffleRepeatSettingAndPreview() {
        studio.currentTabIndex = tabIndex("controls");
        verify(waitForRendering(studio));
        const row = findChild(studio, "row_showShuffleRepeat");
        const body = findChild(studio, "studioBody");
        body.contentY = row.mapToItem(body.contentItem, 0, 0).y - body.height + row.height;
        verify(waitForRendering(studio));
        mouseClick(findChild(studio, "switch_showShuffleRepeat"));
        compare(studio.draft.showShuffleRepeat, true);
        const preview = findChild(studio, "previewWidget");
        verify(waitForRendering(studio));
        mouseClick(findChild(preview, "shuffleArea"));
        compare(preview.player.shuffle, true);
        mouseClick(findChild(preview, "repeatArea"));
        compare(preview.player.loopState, 2);
        mouseClick(findChild(preview, "repeatArea"));
        compare(preview.player.loopState, 1);
        verify(findChild(preview, "repeatAreaBadge").visible);
    }

    function test_wrappedTabsAreReachable_data() {
        return [
            {
                tag: "normal",
                width: 1200
            },
            {
                tag: "narrow",
                width: 440
            }
        ];
    }
    function test_wrappedTabsAreReachable(data) {
        testCase.width = data.width;
        verify(waitForRendering(studio));
        const tabs = findChild(studio, "studioTabs");
        const rows = [];
        for (let index = 0; index < Schema.TABS.length; index++) {
            const tab = findChild(studio, "tabButton_" + index);
            const position = tab.mapToItem(tabs, 0, 0);
            verify(position.x >= 0 && position.x + tab.width <= tabs.width + 0.5);
            verify(position.y >= 0 && position.y + tab.height <= tabs.height + 0.5);
            if (rows.indexOf(position.y) === -1)
                rows.push(position.y);
            mouseClick(tab);
            compare(studio.currentTabIndex, index);
        }
        if (data.tag === "normal")
            compare(rows.length, 2);
        verify(findChild(studio, "studioBody").y >= tabs.y + tabs.height);
    }

    function test_smallSettingsWindow() {
        testCase.width = 590;
        testCase.height = 448;
        verify(waitForRendering(studio));
        const body = findChild(studio, "studioBody");
        const toggle = findChild(studio, "previewOptionsToggle");
        verify(toggle.visible);
        verify(body.height >= 185, "Small dialogs must leave room for settings");
        const preview = findChild(studio, "previewWidget");
        verify(preview.scale >= 0.6, "Collapsed options leave a readable live preview");
        const collapsedHeight = body.height;
        mouseClick(toggle);
        verify(waitForRendering(studio));
        verify(body.height < collapsedHeight);
        mouseClick(toggle);
        verify(waitForRendering(studio));
        compare(body.height, collapsedHeight);
        studio.currentTabIndex = tabIndex("audio");
        verify(waitForRendering(studio));
        verify(studio.anyResults);
    }

    function test_savedLooksHaveTheirOwnTab_data() {
        return [
            {
                tag: "narrow",
                width: 540
            },
            {
                tag: "wide",
                width: 1200
            }
        ];
    }

    function test_savedLooksHaveTheirOwnTab(data) {
        testCase.width = data.width;
        studio.presetFilter = "adaptive";
        verify(waitForRendering(studio));
        const looks = findChild(studio, "section_presets_0");
        const saved = findChild(studio, "section_saved_1");
        verify(!saved.visible, "My presets has its own tab");
        compare(findChild(studio, "userPresetName"), null);
        const builtIn = findChild(studio, "preset_halo");
        verify(builtIn.visible);
        verify(builtIn.mapToItem(looks, 0, builtIn.height).y <= looks.height);
        studio.saveUserPreset("My look");
        mouseClick(findChild(studio, "tabButton_" + tabIndex("saved")));
        verify(waitForRendering(studio));
        verify(saved.visible && !looks.visible);
        compare(findChild(studio, "preset_halo"), null);
        const tile = findChild(studio, "userPreset_0");
        const name = findChild(studio, "userPresetName");
        verify(tile !== null);
        verify(tile.mapToItem(saved, 0, tile.height).y <= name.mapToItem(saved, 0, 0).y, "Save controls must follow the saved thumbnail");
        verify(name.mapToItem(saved, 0, name.height).y <= saved.height);
    }

    function test_colourControlsLiveTogether() {
        studio.currentTabIndex = tabIndex("viz");
        verify(waitForRendering(studio));
        compare(findChild(studio, "row_vizColorMode"), null);
        studio.currentTabIndex = tabIndex("colors");
        verify(waitForRendering(studio));
        verify(findChild(studio, "row_waveSrc").visible);
        verify(findChild(studio, "row_vizColorMode").visible);
        verify(findChild(studio, "row_bloom").visible);
    }

    function test_positionLivesUnderBehaviourOnlyOnHyprland() {
        compare(tabIndex("place"), -1);
        studio.currentTabIndex = tabIndex("behavior");
        verify(waitForRendering(studio));
        const monitor = findChild(studio, "row_monitor");
        verify(monitor !== null && monitor.visible);
        studio.env = "kde";
        verify(waitForRendering(studio));
        compare(findChild(studio, "row_monitor"), null);
        studio.env = "hypr";
    }

    function test_tileGridReservesItsHeight() {
        studio.currentTabIndex = tabIndex("viz");
        verify(waitForRendering(studio));
        const gridRow = findChild(studio, "row_visualizerType");
        const lastTile = findChild(studio, "tile_visualizerType_15");
        const nextRow = findChild(studio, "row_lineWidth");
        verify(lastTile.mapToItem(gridRow, 0, lastTile.height).y <= gridRow.height);
        verify(nextRow.y >= gridRow.y + gridRow.height);
    }

    function test_hiddenStudioStopsPreviewClocks() {
        const preview = findChild(studio, "previewWidget");
        verify(preview !== null);
        studio.visible = false;
        tryCompare(studio.backend, "running", false);
        tryCompare(preview.visualizer, "running", false);
        const tileTime = studio.backend.frameTimeMs;
        const stageTime = preview.visualizer.frameTimeMs;
        wait(160);
        compare(studio.backend.frameTimeMs, tileTime);
        compare(preview.visualizer.frameTimeMs, stageTime);
        studio.visible = true;
        tryCompare(preview.visualizer, "running", true);
    }

    function test_draftLoadsAfterCreation() {
        const fresh = Qt.createComponent("../package/contents/ui/studio/Studio.qml");
        const view = createTemporaryObject(fresh, testCase, {
            width: 1200,
            height: 820
        });
        verify(view !== null);
        compare(findChild(view, "previewWidget"), null);
        view.defaults = defaults;
        view.draft = Object.assign({}, defaults);
        const preview = findChild(view, "previewWidget");
        verify(preview !== null);
        compare(preview.configuration.showMpris, defaults.showMpris);
        const glass = findChild(view, "preset_glass");
        verify(glass !== null);
        compare(glass.settings.titleSize, defaults.titleSize);
        compare(glass.settings.surfaceStyle, "glass");
    }

    function test_previewRendersTheDraft() {
        const preview = findChild(studio, "previewWidget");
        verify(preview !== null);
        studio.update({
            layoutMode: "poster"
        });
        compare(preview.configuration.layoutMode, "poster");
        compare(preview.implicitHeight, 112);
    }
}
