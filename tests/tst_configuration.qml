import QtQuick
import QtTest
import "../hyprland/Configuration.js" as Configuration

TestCase {
    name: "HyprlandConfiguration"
    property string schema
    property var defaults

    function initTestCase() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../package/contents/config/main.xml"), false);
        request.send();
        schema = request.responseText;
        defaults = Configuration.defaults(schema);
    }
    function test_existingDefaults_data() {
        // An upgrade must retain the stored types and the original appearance.
        const entries = {
            visualizerType: ["Int", 0],
            progressBarStyle: ["Int", 0],
            numBars: ["Int", 24],
            sensitivity: ["Int", 100],
            framerate: ["Int", 30],
            noiseReduction: ["Double", 0.77],
            inputMethod: ["String", "auto"],
            showMpris: ["Bool", true],
            alwaysVisible: ["Bool", false],
            useSystemAccent: ["Bool", true],
            customColor: ["String", "#a855f7"],
            lineWidth: ["Double", 1.8],
            fillWave: ["Bool", false],
            showBg: ["Bool", false],
            bgColor: ["String", "#0a0b10"],
            bgRadius: ["Double", 12.0],
            glowWave: ["Bool", true],
            useSystemText: ["Bool", true],
            customTextColor: ["String", "#ffffff"],
            useSystemControls: ["Bool", true],
            customControlColor: ["String", "#ffffff"],
            useSystemDockBg: ["Bool", true],
            customDockBgColor: ["String", "#ffffff"],
            artBg: ["Bool", false],
            artBgDim: ["Double", 0.5],
            artBgBlur: ["Double", 0.22],
            artBgTransparency: ["Double", 1.0],
            showArtThumb: ["Bool", true],
            artBgKeepThumb: ["Bool", false]
        };
        return Object.keys(entries).map(name => ({
                    tag: name,
                    type: entries[name][0],
                    value: entries[name][1]
                }));
    }
    function test_existingDefaults(data) {
        compare(defaults[data.tag], data.value);
        const entry = new RegExp('<entry\\s+name="' + data.tag + '"\\s+type="([^"]+)"').exec(schema);
        verify(entry !== null);
        compare(entry[1], data.type);
    }
    function test_redesignDefaultsUseClassicAndTypedLists() {
        compare(defaults.layoutMode, "classic");
        compare(defaults.surfaceStyle, "color");
        compare(defaults.detailFields, ["album", "genre", "format", "player"]);
        compare(defaults.userPresets, "");
        compare(Configuration.defaults('<entry name="fields" type="StringList"><default></default></entry>').fields, []);
    }
    function test_displaySelectionAndUnplugFallback() {
        const outputs = [
            {
                name: "DP-1"
            },
            {
                name: "HDMI-A-1"
            }
        ];
        compare(Configuration.screens(outputs, "all"), outputs);
        compare(Configuration.screens(outputs, "HDMI-A-1"), [outputs[1]]);
        compare(Configuration.screens(outputs, ""), [outputs[0]]);
        compare(Configuration.screens([outputs[0]], "HDMI-A-1"), [outputs[0]]);
        compare(Configuration.screens([], "all"), []);
        compare(Configuration.screens([], "DP-1"), []);
    }
    function test_onlyChangedPreferencesOverrideNixDefaults() {
        const defaults = {
            monitor: "all",
            sensitivity: 130,
            showBg: false
        };
        const changed = Configuration.overrides(defaults, {
            monitor: "all",
            sensitivity: 175,
            showBg: false
        });
        compare(changed, {
            sensitivity: 175
        });
        compare(Object.assign({}, defaults, changed).monitor, "all");
        compare(Configuration.overrides(defaults, defaults), {});
    }
    function test_stringListsPersistAndResetByValue() {
        const draft = Configuration.parsePreferences(JSON.stringify(defaults));
        compare(Configuration.overrides(defaults, draft), {});
        draft.detailFields = ["player", "album"];
        const changed = Configuration.overrides(defaults, draft);
        compare(changed, {
            detailFields: ["player", "album"]
        });
        const reloaded = Configuration.parsePreferences(JSON.stringify(changed));
        compare(Object.assign({}, defaults, reloaded).detailFields, ["player", "album"]);
        compare(defaults.detailFields, ["album", "genre", "format", "player"]);

        draft.detailFields = [];
        compare(Configuration.overrides(defaults, draft), {
            detailFields: []
        });
        draft.detailFields = ["player", "format", "genre", "album"];
        compare(Configuration.overrides(defaults, draft), {
            detailFields: draft.detailFields
        });
        draft.detailFields = defaults.detailFields.slice();
        compare(Configuration.overrides(defaults, draft), {});
    }
    function test_invalidPreferencesDoNotBecomeSettings() {
        for (const text of ["null", "[]", "false", "not json"]) {
            let failed = false;
            try {
                Configuration.parsePreferences(text);
            } catch (error) {
                failed = true;
            }
            verify(failed, text);
        }
        compare(Configuration.parsePreferences('{"monitor":"all"}'), {
            monitor: "all"
        });
    }
}
