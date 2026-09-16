// Portable look format used by the browser and QML. No desktop placement or
// nested preset library is transferred. Legacy {name, settings} and bare maps work.
var excluded = ['userPresets', 'monitor', 'verticalPosition', 'desktopLayer',
                'pauseWhenCovered', 'hAnchor', 'widgetWidth', 'widgetHeight'];
function object(value) {
    return value !== null && typeof value === 'object' && !Array.isArray(value);
}
function canonical(settings) {
    var out = Object.assign({}, settings);
    if (out.layoutMode === 'compact') {
        out.layoutMode = out._cardLayout || 'classic';
        out.showMpris = false;
    }
    if (out.surfaceStyle === 'art') {
        out.surfaceStyle = out._cardSurface || 'color';
        out.artBg = true;
    }
    if (out.detailFields !== undefined) {
        if (!Array.isArray(out.detailFields) && typeof out.detailFields !== 'string')
            throw new Error('Track details must be a list.');
        out.detailFields = (Array.isArray(out.detailFields) ? out.detailFields : out.detailFields.split(','))
            .map(function (v) { return String(v).trim(); }).filter(Boolean);
    }
    return out;
}
function clean(settings, known) {
    var input = canonical(settings), out = {};
    Object.keys(input).forEach(function (key) {
        if (!Object.prototype.hasOwnProperty.call(known, key) || excluded.indexOf(key) !== -1
            || key === '__proto__' || key === 'constructor' || key === 'prototype') return;
        var value = input[key];
        if (key === 'detailFields') out[key] = value;
        else if (typeof value === typeof known[key] && !object(value) && !Array.isArray(value)
                 && (typeof value !== 'number' || isFinite(value))) out[key] = value;
        else throw new Error('Invalid value for ' + key + '.');
    });
    return out;
}
function browser(settings) {
    var out = Object.assign({}, settings);
    if (out.showMpris === false && out.layoutMode !== 'pill' && out.layoutMode !== 'pillicon') {
        out._cardLayout = out.layoutMode || 'classic';
        out.layoutMode = 'compact';
    }
    if (out.artBg === true) {
        out._cardSurface = out.surfaceStyle || 'color';
        out.surfaceStyle = 'art';
    }
    if (Array.isArray(out.detailFields)) out.detailFields = out.detailFields.join(',');
    return out;
}
function encode(name, settings, known, fromBrowser) {
    var input = Object.assign({}, settings);
    if (fromBrowser) {
        input.showMpris = input.layoutMode === 'compact' ? false
            : (input.layoutMode === 'pill' || input.layoutMode === 'pillicon') ? input.showMpris !== false : true;
        input.artBg = input.surfaceStyle === 'art';
    }
    return JSON.stringify({format: 'plasma-audio-visualizer-look', version: 1,
        name: String(name || 'Shared look'), settings: clean(input, known)});
}
function decode(text, known, forBrowser) {
    var data = JSON.parse(text);
    if (!object(data)) throw new Error('Paste a look object.');
    if (data.format !== undefined && (data.format !== 'plasma-audio-visualizer-look' || data.version !== 1))
        throw new Error('Unsupported look format.');
    var settings = data.settings === undefined ? data : data.settings;
    if (!object(settings)) throw new Error('Settings must be an object.');
    var result = clean(settings, known);
    return {name: typeof data.name === 'string' ? data.name : 'Imported look',
            settings: forBrowser ? browser(result) : result};
}

// Browser namespace; QML also exposes the top-level functions through its import.
var PresetCodec = {encode: encode, decode: decode, browser: browser};
