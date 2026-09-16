import QtQuick
import QtTest
import "../package/contents/ui/studio/PresetCodec.js" as Codec
import "../package/contents/ui/studio/Schema.js" as Schema

TestCase {
    name: "PresetExchange"
    property var known: ({
            layoutMode: 'classic',
            showMpris: true,
            surfaceStyle: 'color',
            artBg: false,
            detailFields: ['album', 'year'],
            titleSize: 11,
            customColor: '#123456',
            monitor: '',
            widgetWidth: 360,
            userPresets: ''
        })

    function test_qmlBrowserQml_data() {
        return [
            {
                tag: 'classic',
                mode: 'classic',
                show: true,
                art: false
            },
            {
                tag: 'compact',
                mode: 'poster',
                show: false,
                art: true
            },
            {
                tag: 'pill',
                mode: 'pill',
                show: false,
                art: true
            }
        ];
    }
    function test_qmlBrowserQml(data) {
        const state = Object.assign({}, known, {
            layoutMode: data.mode,
            showMpris: data.show,
            surfaceStyle: 'glass',
            artBg: data.art,
            detailFields: ['album', 'genre'],
            monitor: 'DP-1',
            userPresets: 'private library'
        });
        const text = Schema.exportPreset('Round trip', state, known);
        const web = Codec.decode(text, known, true);
        compare(web.settings.detailFields, 'album,genre');
        compare(web.settings.surfaceStyle, data.art ? 'art' : 'glass');
        const result = Schema.importPreset(Codec.encode(web.name, web.settings, known, true), known);
        compare(result.name, 'Round trip');
        compare(result.settings.layoutMode, data.mode);
        compare(result.settings.showMpris, data.show);
        compare(result.settings.surfaceStyle, 'glass');
        compare(result.settings.artBg, data.art);
        compare(result.settings.detailFields, ['album', 'genre']);
        verify(result.settings.monitor === undefined);
        verify(result.settings.userPresets === undefined);
        verify(result.settings.widgetWidth === undefined);
        // Explicit defaults survive a destination with different defaults.
        compare(result.settings.titleSize, known.titleSize);
    }
    function test_legacyBrowserToQml() {
        const imported = Schema.importPreset(JSON.stringify({
            name: 'Old browser look',
            settings: {
                layoutMode: 'compact',
                surfaceStyle: 'art',
                detailFields: 'album, year',
                unknown: 4
            }
        }), known);
        compare(imported.settings.showMpris, false);
        compare(imported.settings.artBg, true);
        compare(imported.settings.detailFields, ['album', 'year']);
        verify(imported.settings.unknown === undefined);
    }
    function test_invalid_data() {
        return ['null', '[]', '{"settings":[]}', '{"settings":{"titleSize":"bad"}}', '{"format":"plasma-audio-visualizer-look","version":99,"settings":{}}'].map((text, index) => ({
                    tag: String(index),
                    text: text
                }));
    }
    function test_invalid(data) {
        let threw = false;
        try {
            Schema.importPreset(data.text, known);
        } catch (error) {
            threw = true;
        }
        verify(threw);
    }
}
